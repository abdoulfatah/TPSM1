;;; cua-rect.el --- CUA unified rectangle support

;; Copyright (C) 1997-2015 Free Software Foundation, Inc.

;; Author: Kim F. Storm <storm@cua.dk>
;; Keywords: keyboard emulations convenience CUA
;; Package: cua-base

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Acknowledgments

;; The rectangle handling and display code borrows from the standard
;; GNU emacs rect.el package and the rect-mark.el package by Rick
;; Sladkey <jrs@world.std.com>.

;;; Commentary:

;;; Code:

(require 'cua-base)

;;; Rectangle support

(require 'rect)

;; If non-nil, restrict current region to this rectangle.
;; Value is a vector [top bot left right corner ins virt select].
;; CORNER specifies currently active corner 0=t/l 1=t/r 2=b/l 3=b/r.
;; INS specifies whether to insert on left(nil) or right(t) side.
;; If VIRT is non-nil, virtual straight edges are enabled.
;; If SELECT is a regexp, only lines starting with that regexp are affected.")
(defvar cua--rectangle nil)
(make-variable-buffer-local 'cua--rectangle)

;; Most recent rectangle geometry.  Note: car is buffer.
(defvar cua--last-rectangle nil)

;; Rectangle restored by undo.
(defvar cua--restored-rectangle nil)

;; Last rectangle copied/killed; nil if last kill was not a rectangle.
(defvar cua--last-killed-rectangle nil)

;; List of overlays used to display current rectangle.
(defvar cua--rectangle-overlays nil)
(make-variable-buffer-local 'cua--rectangle-overlays)
(put 'cua--rectangle-overlays 'permanent-local t)

(defvar cua--overlay-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "\r" 'cua-rotate-rectangle)))

(defvar cua--virtual-edges-debug nil)

;; Undo rectangle commands.

(defvar cua--rect-undo-set-point nil)

(defun cua--rectangle-undo-boundary ()
  (when (listp buffer-undo-list)
    (let ((s (cua--rect-start-position))
	  (e (cua--rect-end-position)))
      (undo-boundary)
      (push (list 'apply 0 s e
		  'cua--rect-undo-handler
		  (copy-sequence cua--rectangle) t s e)
            buffer-undo-list))))

(defun cua--rect-undo-handler (rect on s e)
  (if (setq on (not on))
      (setq cua--rect-undo-set-point s)
    (setq cua--restored-rectangle (copy-sequence rect))
    (setq cua--buffer-and-point-before-command nil))
  (push (list 'apply 0 s (if on e s)
	      'cua--rect-undo-handler rect on s e)
	buffer-undo-list))

;;;###autoload
(define-minor-mode cua-rectangle-mark-mode
  "Toggle the region as rectangular.
Activates the region if needed.  Only lasts until the region is deactivated."
  :keymap cua--rectangle-keymap
  (cond
   (cua-rectangle-mark-mode
    (add-hook 'deactivate-mark-hook
              (lambda () (cua-rectangle-mark-mode -1)))
    (add-hook 'post-command-hook #'cua--rectangle-post-command nil t)
    (cua-set-rectangle-mark))
   (t
    (cua--deactivate-rectangle)
    (remove-hook 'post-command-hook #'cua--rectangle-post-command t))))

;;; Rectangle geometry

(defun cua--rectangle-top (&optional val)
  ;; Top of CUA rectangle (buffer position on first line).
  (if (not val)
      (aref cua--rectangle 0)
    (setq val (line-beginning-position))
    (if (<= val (aref cua--rectangle 1))
        (aset cua--rectangle 0 val)
      (aset cua--rectangle 1 val)
      (cua--rectangle-corner 2))))

(defun cua--rectangle-bot (&optional val)
  ;; Bot of CUA rectangle (buffer position on last line).
  (if (not val)
      (aref cua--rectangle 1)
    (setq val (line-end-position))
    (if (>= val (aref cua--rectangle 0))
        (aset cua--rectangle 1 val)
      (aset cua--rectangle 0 val)
      (cua--rectangle-corner 2))))

(defun cua--rectangle-left (&optional val)
  ;; Left column of CUA rectangle.
  (if (integerp val)
      (if (<= val (aref cua--rectangle 3))
          (aset cua--rectangle 2 val)
        (aset cua--rectangle 3 val)
        (cua--rectangle-corner (if (cua--rectangle-right-side) -1 1)))
    (aref cua--rectangle 2)))

(defun cua--rectangle-right (&optional val)
  ;; Right column of CUA rectangle.
  (if (integerp val)
      (if (>= val (aref cua--rectangle 2))
          (aset cua--rectangle 3 val)
        (aset cua--rectangle 2 val)
        (cua--rectangle-corner (if (cua--rectangle-right-side) -1 1)))
    (aref cua--rectangle 3)))

(defun cua--rectangle-corner (&optional advance)
  ;; Currently active corner of rectangle.
  (let ((c (aref cua--rectangle 4)))
    (if (not (integerp advance))
        c
      (aset cua--rectangle 4
            (if (= advance 0)
                (- 3 c) ; opposite corner
              (mod (+ c 4 advance) 4)))
      (aset cua--rectangle 5 0))))

(defun cua--rectangle-right-side (&optional topbot)
  ;; t if point is on right side of rectangle.
  (if (and topbot (= (cua--rectangle-left) (cua--rectangle-right)))
      (< (cua--rectangle-corner) 2)
    (= (mod (cua--rectangle-corner) 2) 1)))

(defun cua--rectangle-column ()
  (if (cua--rectangle-right-side)
      (cua--rectangle-right)
    (cua--rectangle-left)))

(defun cua--rectangle-insert-col (&optional col)
  ;; Currently active corner of rectangle.
  (if (integerp col)
      (aset cua--rectangle 5 col)
    (if (cua--rectangle-right-side t)
        (if (= (aref cua--rectangle 5) 0)
            (1+ (cua--rectangle-right))
          (aref cua--rectangle 5))
      (cua--rectangle-left))))

(defun cua--rectangle-virtual-edges (&optional set val)
  ;; Current setting of rectangle virtual-edges
  (if set
      (aset cua--rectangle 6 val))
  (and ;(not buffer-read-only)
       (aref cua--rectangle 6)))

(defun cua--rectangle-restriction (&optional val bounded negated)
  ;; Current rectangle restriction
  (if val
      (aset cua--rectangle 7
            (and (stringp val)
             (> (length val) 0)
             (list val bounded negated)))
    (aref cua--rectangle 7)))

(defun cua--rectangle-assert ()
  (message "%S (%d)" cua--rectangle (point))
  (if (< (cua--rectangle-right) (cua--rectangle-left))
      (message "rectangle right < left"))
  (if (< (cua--rectangle-bot) (cua--rectangle-top))
      (message "rectangle bot < top")))

(defun cua--rectangle-get-corners ()
  ;; Calculate the rectangular region represented by point and mark,
  ;; putting start in the upper left corner and end in the
  ;; bottom right corner.
  (let ((top (point)) (bot (mark)) r l corner)
    (save-excursion
      (goto-char top)
      (setq l (current-column))
      (goto-char bot)
      (setq r (current-column))
      (if (<= top bot)
          (setq corner (if (<= l r) 0 1))
        (setq top (prog1 bot (setq bot top)))
        (setq corner (if (<= l r) 2 3)))
      (if (<= l r)
          (if (< l r)
              (setq r (1- r)))
        (setq l (prog1 r (setq r l)))
        (goto-char top)
        (move-to-column l)
        (setq top (point))
        (goto-char bot)
        (move-to-column r)
        (setq bot (point))))
    (vector top bot l r corner 0 cua-virtual-rectangle-edges nil)))

(defun cua--rectangle-set-corners ()
  ;; Set mark and point in opposite corners of current rectangle.
  (let (pp pc mp mc (c (cua--rectangle-corner)))
    (cond
     ((= c 0)  ; top/left -> bot/right
      (setq pp (cua--rectangle-top) pc (cua--rectangle-left)
            mp (cua--rectangle-bot) mc (cua--rectangle-right)))
     ((= c 1)  ; top/right -> bot/left
      (setq pp (cua--rectangle-top) pc (cua--rectangle-right)
            mp (cua--rectangle-bot) mc (cua--rectangle-left)))
     ((= c 2)  ; bot/left -> top/right
      (setq pp (cua--rectangle-bot) pc (cua--rectangle-left)
            mp (cua--rectangle-top) mc (cua--rectangle-right)))
     ((= c 3)  ; bot/right -> top/left
      (setq pp (cua--rectangle-bot) pc (cua--rectangle-right)
            mp (cua--rectangle-top) mc (cua--rectangle-left))))
    (goto-char mp)
    (move-to-column mc)
    (set-mark (point))
    (goto-char pp)
    ;; Move cursor inside rectangle, except if char at right edge is a tab.
    (if (and (if (cua--rectangle-right-side)
		 (and (= (move-to-column pc) (- pc tab-width))
		      (not (eolp)))
	       (> (move-to-column pc) pc))
	     (not (bolp)))
	(backward-char 1))
    ))

(defun cua--rect-start-position ()
  ;; Return point of top left corner
  (save-excursion
    (goto-char (cua--rectangle-top))
    (and (> (move-to-column (cua--rectangle-left))
	    (cua--rectangle-left))
	 (not (bolp))
	 (backward-char 1))
    (point)))

(defun cua--rect-end-position ()
  ;; Return point of bottom right cornet
  (save-excursion
    (goto-char (cua--rectangle-bot))
    (and (= (move-to-column (cua--rectangle-right))
	    (- (cua--rectangle-right) tab-width))
	 (not (eolp))
	 (not (bolp))
	 (backward-char 1))
    (point)))

;;; Rectangle resizing

(defun cua--forward-line (n)
  ;; Move forward/backward one line.  Returns t if movement.
  (let ((pt (point)))
    (and (= (forward-line n) 0)
	 ;; Deal with end of buffer
	 (or (not (eobp))
	     (goto-char pt)))))

(defun cua--rectangle-resized ()
  ;; Refresh state after resizing rectangle
  (setq cua--buffer-and-point-before-command nil)
  (cua--rectangle-insert-col 0)
  (cua--rectangle-set-corners)
  (cua--keep-active))

(defun cua-resize-rectangle-right (n)
  "Resize rectangle to the right."
  (interactive "p")
  (let ((resized (> n 0)))
    (while (> n 0)
      (setq n (1- n))
      (cond
       ((cua--rectangle-right-side)
        (cua--rectangle-right (1+ (cua--rectangle-right)))
        (move-to-column (cua--rectangle-right)))
       (t
        (cua--rectangle-left (1+ (cua--rectangle-left)))
        (move-to-column (cua--rectangle-right)))))
    (if resized
        (cua--rectangle-resized))))

(defun cua-resize-rectangle-left (n)
  "Resize rectangle to the left."
  (interactive "p")
  (let (resized)
    (while (> n 0)
      (setq n (1- n))
      (if (or (= (cua--rectangle-right) 0)
              (and (not (cua--rectangle-right-side)) (= (cua--rectangle-left) 0)))
          (setq n 0)
        (cond
         ((cua--rectangle-right-side)
          (cua--rectangle-right (1- (cua--rectangle-right)))
          (move-to-column (cua--rectangle-right)))
         (t
          (cua--rectangle-left (1- (cua--rectangle-left)))
          (move-to-column (cua--rectangle-right))))
        (setq resized t)))
    (if resized
        (cua--rectangle-resized))))

(defun cua-resize-rectangle-down (n)
  "Resize rectangle downwards."
  (interactive "p")
  (let (resized)
    (while (> n 0)
      (setq n (1- n))
      (cond
       ((>= (cua--rectangle-corner) 2)
        (goto-char (cua--rectangle-bot))
        (when (cua--forward-line 1)
          (move-to-column (cua--rectangle-column))
          (cua--rectangle-bot t)
          (setq resized t)))
       (t
        (goto-char (cua--rectangle-top))
        (when (cua--forward-line 1)
          (move-to-column (cua--rectangle-column))
          (cua--rectangle-top t)
          (setq resized t)))))
    (if resized
        (cua--rectangle-resized))))

(defun cua-resize-rectangle-up (n)
  "Resize rectangle upwards."
  (interactive "p")
  (let (resized)
    (while (> n 0)
      (setq n (1- n))
      (cond
       ((>= (cua--rectangle-corner) 2)
        (goto-char (cua--rectangle-bot))
        (when (cua--forward-line -1)
          (move-to-column (cua--rectangle-column))
          (cua--rectangle-bot t)
          (setq resized t)))
       (t
        (goto-char (cua--rectangle-top))
        (when (cua--forward-line -1)
          (move-to-column (cua--rectangle-column))
          (cua--rectangle-top t)
          (setq resized t)))))
    (if resized
        (cua--rectangle-resized))))

(defun cua-resize-rectangle-eol ()
  "Resize rectangle to end of line."
  (interactive)
  (unless (eolp)
    (end-of-line)
    (if (> (current-column) (cua--rectangle-right))
        (cua--rectangle-right (current-column)))
    (if (not (cua--rectangle-right-side))
        (cua--rectangle-corner 1))
    (cua--rectangle-resized)))

(defun cua-resize-rectangle-bol ()
  "Resize rectangle to beginning of line."
  (interactive)
  (unless (bolp)
    (beginning-of-line)
    (cua--rectangle-left (current-column))
    (if (cua--rectangle-right-side)
        (cua--rectangle-corner -1))
    (cua--rectangle-resized)))

(defun cua-resize-rectangle-bot ()
  "Resize rectangle to bottom of buffer."
  (interactive)
  (goto-char (point-max))
  (move-to-column (cua--rectangle-column))
  (cua--rectangle-bot t)
  (cua--rectangle-resized))

(defun cua-resize-rectangle-top ()
  "Resize rectangle to top of buffer."
  (interactive)
  (goto-char (point-min))
  (move-to-column (cua--rectangle-column))
  (cua--rectangle-top t)
  (cua--rectangle-resized))

(defun cua-resize-rectangle-page-up ()
  "Resize rectangle upwards by one scroll page."
  (interactive)
  (scroll-down)
  (move-to-column (cua--rectangle-column))
  (if (>= (cua--rectangle-corner) 2)
      (cua--rectangle-bot t)
    (cua--rectangle-top t))
  (cua--rectangle-resized))

(defun cua-resize-rectangle-page-down ()
  "Resize rectangle downwards by one scroll page."
  (interactive)
  (scroll-up)
  (move-to-column (cua--rectangle-column))
  (if (>= (cua--rectangle-corner) 2)
      (cua--rectangle-bot t)
    (cua--rectangle-top t))
  (cua--rectangle-resized))

;;; Mouse support

;; This is pretty simplistic, but it does the job...

(defun cua-mouse-resize-rectangle (event)
  "Set rectangle corner at mouse click position."
  (interactive "e")
  (mouse-set-point event)
  ;; FIX ME -- need to calculate virtual column.
  (if (cua--rectangle-virtual-edges)
      (move-to-column (car (posn-col-row (event-end event))) t))
  (if (cua--rectangle-right-side)
      (cua--rectangle-right (current-column))
    (cua--rectangle-left (current-column)))
  (if (>= (cua--rectangle-corner) 2)
      (cua--rectangle-bot t)
    (cua--rectangle-top t))
  (cua--rectangle-resized))

(defvar cua--mouse-last-pos nil)

(defun cua-mouse-set-rectangle-mark (event)
  "Start rectangle at mouse click position."
  (interactive "e")
  (when cua--rectangle
    (cua--deactivate-rectangle)
    (cua--deactivate t))
  (setq cua--last-rectangle nil)
  (mouse-set-point event)
  ;; FIX ME -- need to calculate virtual column.
  (cua-set-rectangle-mark)
  (setq cua--buffer-and-point-before-command nil)
  (setq cua--mouse-last-pos nil))

(defun cua-mouse-save-then-kill-rectangle (event arg)
  "Expand rectangle to mouse click position and copy rectangle.
If command is repeated at same position, delete the rectangle."
  (interactive "e\nP")
  (if (and (eq this-command last-command)
           (eq (point) (car-safe cua--mouse-last-pos))
           (eq cua--last-killed-rectangle (cdr-safe cua--mouse-last-pos)))
      (progn
        (unless buffer-read-only
          (cua--delete-rectangle))
        (cua--deactivate))
    (cua-mouse-resize-rectangle event)
    (let ((cua-keep-region-after-copy t))
      (cua-copy-region arg)
      (setq cua--mouse-last-pos (cons (point) cua--last-killed-rectangle)))))

(defun cua--mouse-ignore (_event)
  (interactive "e")
  (setq this-command last-command))

(defun cua--rectangle-move (dir)
  (let ((moved t)
        (top (cua--rectangle-top))
        (bot (cua--rectangle-bot))
        (l (cua--rectangle-left))
        (r (cua--rectangle-right)))
    (cond
     ((eq dir 'up)
      (goto-char top)
      (when (cua--forward-line -1)
        (cua--rectangle-top t)
        (goto-char bot)
        (forward-line -1)
        (cua--rectangle-bot t)))
     ((eq dir 'down)
      (goto-char bot)
      (when (cua--forward-line 1)
        (cua--rectangle-bot t)
        (goto-char top)
        (cua--forward-line 1)
        (cua--rectangle-top t)))
     ((eq dir 'left)
      (when (> l 0)
        (cua--rectangle-left (1- l))
        (cua--rectangle-right (1- r))))
     ((eq dir 'right)
      (cua--rectangle-right (1+ r))
      (cua--rectangle-left (1+ l)))
     (t
      (setq moved nil)))
    (when moved
      (setq cua--buffer-and-point-before-command nil)
      (cua--rectangle-set-corners)
      (cua--keep-active))))


;;; Operations on current rectangle

(defun cua--tabify-start (start end)
  ;; Return position where auto-tabify should start (or nil if not required).
  (save-excursion
    (save-restriction
      (widen)
      (and (not buffer-read-only)
	   cua-auto-tabify-rectangles
	   (if (or (not (integerp cua-auto-tabify-rectangles))
		   (= (point-min) (point-max))
		   (progn
		     (goto-char (max (point-min)
				     (- start cua-auto-tabify-rectangles)))
		     (search-forward "\t" (min (point-max)
					       (+ end cua-auto-tabify-rectangles)) t)))
	       start)))))

(defun cua--rectangle-operation (keep-clear visible undo pad tabify &optional fct post-fct)
  ;; Call FCT for each line of region with 4 parameters:
  ;; Region start, end, left-col, right-col
  ;; Point is at start when FCT is called
  ;; Call fct with (s,e) = whole lines if VISIBLE non-nil.
  ;; Only call fct for visible lines if VISIBLE==t.
  ;; Set undo boundary if UNDO is non-nil.
  ;; Rectangle is padded if PAD = t or numeric and (cua--rectangle-virtual-edges)
  ;; Perform auto-tabify after operation if TABIFY is non-nil.
  ;; Mark is kept if keep-clear is 'keep and cleared if keep-clear is 'clear.
  (let* ((inhibit-field-text-motion t)
	 (start (cua--rectangle-top))
         (end   (cua--rectangle-bot))
         (l (cua--rectangle-left))
         (r (1+ (cua--rectangle-right)))
         (m (make-marker))
         (tabpad (and (integerp pad) (= pad 2)))
         (sel (cua--rectangle-restriction))
	 (tabify-start (and tabify (cua--tabify-start start end))))
    (if undo
        (cua--rectangle-undo-boundary))
    (if (integerp pad)
        (setq pad (cua--rectangle-virtual-edges)))
    (save-excursion
      (save-restriction
        (widen)
        (when (> (cua--rectangle-corner) 1)
          (goto-char end)
          (and (bolp) (not (eolp)) (not (eobp))
               (setq end (1+ end))))
        (when (eq visible t)
          (setq start (max (window-start) start))
          (setq end   (min (window-end) end)))
        (goto-char end)
        (setq end (line-end-position))
	(if (and visible (bolp) (not (eobp)))
	    (setq end (1+ end)))
        (goto-char start)
        (setq start (line-beginning-position))
        (narrow-to-region start end)
        (goto-char (point-min))
        (while (< (point) (point-max))
          (move-to-column r pad)
          (and (not pad) (not visible) (> (current-column) r)
               (backward-char 1))
          (if (and tabpad (not pad) (looking-at "\t"))
              (forward-char 1))
          (set-marker m (point))
          (move-to-column l pad)
          (if (and fct (or visible (and (>= (current-column) l) (<= (current-column) r))))
              (let ((v t) (p (point)))
                (when sel
                  (if (car (cdr sel))
                      (setq v (looking-at (car sel)))
                    (setq v (re-search-forward (car sel) m t))
                    (goto-char p))
                  (if (car (cdr (cdr sel)))
                      (setq v (null v))))
                (if visible
		    (funcall fct p m l r v)
                  (if v
                      (funcall fct p m l r)))))
          (set-marker m nil)
          (forward-line 1))
        (if (not visible)
            (cua--rectangle-bot t))
        (if post-fct
            (funcall post-fct l r))
	(when tabify-start
	  (tabify tabify-start (point)))))
    (cond
     ((eq keep-clear 'keep)
      (cua--keep-active))
     ((eq keep-clear 'clear)
      (cua--deactivate))
     ((eq keep-clear 'corners)
      (cua--rectangle-set-corners)
      (cua--keep-active)))
    (setq cua--buffer-and-point-before-command nil)))

(put 'cua--rectangle-operation 'lisp-indent-function 4)

(defun cua--delete-rectangle ()
  (let ((lines 0))
    (if (not (cua--rectangle-virtual-edges))
	(cua--rectangle-operation nil nil t 2 t
	  (lambda (s e _l _r _v)
            (setq lines (1+ lines))
            (if (and (> e s) (<= e (point-max)))
                (delete-region s e))))
      (cua--rectangle-operation nil 1 t nil t
	(lambda (s e _l _r _v)
	   (setq lines (1+ lines))
	   (when (and (> e s) (<= e (point-max)))
	     (delete-region s e)))))
    lines))

(defun cua--extract-rectangle ()
  (let (rect)
    (if (not (cua--rectangle-virtual-edges))
	(cua--rectangle-operation nil nil nil nil nil ; do not tabify
	  (lambda (s e _l _r)
	     (setq rect (cons (cua--filter-buffer-noprops s e) rect))))
      (cua--rectangle-operation nil 1 nil nil nil ; do not tabify
	(lambda (s e l r _v)
	   (let ((copy t) (bs 0) (as 0) row)
	     (if (= s e) (setq e (1+ e)))
	     (goto-char s)
	     (move-to-column l)
	     (if (= (point) (line-end-position))
		 (setq bs (- r l)
		       copy nil)
	       (skip-chars-forward "\s\t" e)
	       (setq bs (- (min r (current-column)) l)
		     s (point))
	       (move-to-column r)
	       (skip-chars-backward "\s\t" s)
	       (setq as (- r (max (current-column) l))
		     e (point)))
       	     (setq row (if (and copy (> e s))
			   (cua--filter-buffer-noprops s e)
			 ""))
    	     (when (> bs 0)
    	       (setq row (concat (make-string bs ?\s) row)))
    	     (when (> as 0)
    	       (setq row (concat row (make-string as ?\s))))
    	     (setq rect (cons row rect))))))
    (nreverse rect)))

(defun cua--insert-rectangle (rect &optional below paste-column line-count)
  ;; Insert rectangle as insert-rectangle, but don't set mark and exit with
  ;; point at either next to top right or below bottom left corner
  ;; Notice: In overwrite mode, the rectangle is inserted as separate text lines.
  (if (eq below 'auto)
      (setq below (and (bolp)
                       (or (eolp) (eobp) (= (1+ (point)) (point-max))))))
  (unless paste-column
    (setq paste-column (current-column)))
  (let ((lines rect)
        (first t)
	(tabify-start (cua--tabify-start (point) (point)))
	last-column
        p)
    (while (or lines below)
      (or first
          (if overwrite-mode
              (insert ?\n)
            (forward-line 1)
            (or (bolp) (insert ?\n))))
      (unless overwrite-mode
	(move-to-column paste-column t))
      (if (not lines)
          (setq below nil)
        (insert-for-yank (car lines))
	(unless last-column
	  (setq last-column (current-column)))
        (setq lines (cdr lines))
        (and first (not below)
             (setq p (point))))
      (setq first nil)
      (if (and line-count (= (setq line-count (1- line-count)) 0))
	  (setq lines nil)))
    (when (and line-count last-column (not overwrite-mode))
      (while (> line-count 0)
	(forward-line 1)
	(or (bolp) (insert ?\n))
	(move-to-column paste-column t)
        (insert-char ?\s (- last-column paste-column -1))
	(setq line-count (1- line-count))))
    (when (and tabify-start
	       (not overwrite-mode))
      (tabify tabify-start (point)))
    (and p (not overwrite-mode)
         (goto-char p))))

(defun cua--copy-rectangle-as-kill (&optional ring)
  (if cua--register
      (set-register cua--register (cua--extract-rectangle))
    (setq killed-rectangle (cua--extract-rectangle))
    (setq cua--last-killed-rectangle (cons (and kill-ring (car kill-ring)) killed-rectangle))
    (if ring
        (kill-new (mapconcat
                   (function (lambda (row) (concat row "\n")))
                   killed-rectangle "")))))

(defun cua--activate-rectangle ()
  ;; Set cua--rectangle to indicate we're marking a rectangle.
  ;; Be careful if we are already marking a rectangle.
  (setq cua--rectangle
        (or (and cua--last-rectangle
                 (eq (car cua--last-rectangle) (current-buffer))
                 (eq (car (cdr cua--last-rectangle)) (point))
                 (cdr (cdr cua--last-rectangle)))
            (cua--rectangle-get-corners))
        cua--status-string (if (cua--rectangle-virtual-edges) " [R]" "")
        cua--last-rectangle nil)
  (activate-mark))

;; (defvar cua-save-point nil)

(defun cua--deactivate-rectangle ()
  ;; This is used to clean up after `cua--activate-rectangle'.
  (mapc #'delete-overlay cua--rectangle-overlays)
  (setq cua--last-rectangle (cons (current-buffer)
                                  (cons (point) ;; cua-save-point
                                        cua--rectangle))
        cua--rectangle nil
        cua--rectangle-overlays nil
        cua--status-string nil
        cua--mouse-last-pos nil)
  ;; FIXME: This call to cua-rectangle-mark-mode is a workaround.
  ;; Deactivation can happen in various different ways, and we
  ;; currently don't handle them all in a coherent way.
  (if cua-rectangle-mark-mode (cua-rectangle-mark-mode -1)))

(defun cua--highlight-rectangle ()
  ;; This function is used to highlight the rectangular region.
  ;; We do this by putting an overlay on each line within the rectangle.
  ;; Each overlay extends across all the columns of the rectangle.
  ;; We try to reuse overlays where possible because this is more efficient
  ;; and results in less flicker.
  ;; If cua--rectangle-virtual-edges is nil and the buffer contains tabs or short lines,
  ;; the highlighted region may not be perfectly rectangular.
  (let ((deactivate-mark deactivate-mark)
        (old cua--rectangle-overlays)
        (new nil)
        (left (cua--rectangle-left))
        (right (1+ (cua--rectangle-right))))
    (when (/= left right)
      (sit-for 0)  ; make window top/bottom reliable
      (cua--rectangle-operation nil t nil nil nil ; do not tabify
        (lambda (s e l r v)
           (let ((rface (if v 'cua-rectangle 'cua-rectangle-noselect))
                 overlay bs ms as)
	     (when (cua--rectangle-virtual-edges)
	       (let ((lb (line-beginning-position))
		     (le (line-end-position))
		     cl cl0 pl cr cr0 pr)
		 (goto-char s)
		 (setq cl (move-to-column l)
		       pl (point))
		 (setq cr (move-to-column r)
		       pr (point))
		 (if (= lb pl)
		     (setq cl0 0)
		   (goto-char (1- pl))
		   (setq cl0 (current-column)))
		 (if (= lb le)
		     (setq cr0 0)
		   (goto-char (1- pr))
		   (setq cr0 (current-column)))
		 (unless (and (= cl l) (= cr r))
		   (when (/= cl l)
		     (setq bs (propertize
			       (make-string
				(- l cl0 (if (and (= le pl) (/= le lb)) 1 0))
				(if cua--virtual-edges-debug ?. ?\s))
			       'face (or (get-text-property (max (1- s) (point-min)) 'face) 'default)))
		     (if (/= pl le)
			 (setq s (1- s))))
		   (cond
		    ((= cr r)
		     (if (and (/= pr le)
			      (/= cr0 (1- cr))
			      (or bs (/= cr0 (- cr tab-width)))
			      (/= (mod cr tab-width) 0))
			 (setq e (1- e))))
		    ((= cr cl)
		     (setq ms (propertize
			       (make-string
				(- r l)
				(if cua--virtual-edges-debug ?, ?\s))
			       'face rface))
		     (if (cua--rectangle-right-side)
			 (put-text-property (1- (length ms)) (length ms) 'cursor 2 ms)
		       (put-text-property 0 1 'cursor 2 ms))
		     (setq bs (concat bs ms))
		     (setq rface nil))
 		    (t
		     (setq as (propertize
			       (make-string
				(- r cr0 (if (= le pr) 1 0))
				(if cua--virtual-edges-debug ?~ ?\s))
			       'face rface))
		     (if (cua--rectangle-right-side)
			 (put-text-property (1- (length as)) (length as) 'cursor 2 as)
		       (put-text-property 0 1 'cursor 2 as))
		     (if (/= pr le)
			 (setq e (1- e))))))))
	     ;; Trim old leading overlays.
             (while (and old
                         (setq overlay (car old))
                         (< (overlay-start overlay) s)
                         (/= (overlay-end overlay) e))
               (delete-overlay overlay)
               (setq old (cdr old)))
             ;; Reuse an overlay if possible, otherwise create one.
             (if (and old
                      (setq overlay (car old))
                      (or (= (overlay-start overlay) s)
                          (= (overlay-end overlay) e)))
                 (progn
                   (move-overlay overlay s e)
                   (setq old (cdr old)))
               (setq overlay (make-overlay s e)))
 	     (overlay-put overlay 'before-string bs)
	     (overlay-put overlay 'after-string as)
	     (overlay-put overlay 'face rface)
	     (overlay-put overlay 'keymap cua--overlay-keymap)
	     (overlay-put overlay 'window (selected-window))
	     (setq new (cons overlay new))))))
    ;; Trim old trailing overlays.
    (mapc (function delete-overlay) old)
    (setq cua--rectangle-overlays (nreverse new))))

(defun cua--indent-rectangle (&optional ch to-col clear)
  ;; Indent current rectangle.
  (let ((col (cua--rectangle-insert-col))
        (pad (cua--rectangle-virtual-edges))
        indent)
    (cua--rectangle-operation (if clear 'clear 'corners) nil t pad nil
      (lambda (_s _e l _r)
         (move-to-column col pad)
         (if (and (eolp)
                  (< (current-column) col))
             (move-to-column col t))
	 (cond
	  (to-col (indent-to to-col))
	  ((and ch (not (eq ch ?\t))) (insert ch))
	  (t (tab-to-tab-stop)))
         (if (cua--rectangle-right-side t)
             (cua--rectangle-insert-col (current-column))
           (setq indent (- (current-column) l))))
      (lambda (l r)
         (when (and indent (> indent 0))
           (aset cua--rectangle 2 (+ l indent))
           (aset cua--rectangle 3 (+ r indent -1)))))))

;;
;; rectangle functions / actions
;;

(defvar cua--rectangle-initialized nil)

(defun cua-set-rectangle-mark (&optional reopen)
  "Set mark and start in CUA rectangle mode.
With prefix argument, activate previous rectangle if possible."
  (interactive "P")
  (unless cua--rectangle-initialized
    (cua--init-rectangles))
  (when (not cua--rectangle)
    (if (and reopen
             cua--last-rectangle
             (eq (car cua--last-rectangle) (current-buffer)))
        (goto-char (car (cdr cua--last-rectangle)))
      (if (not mark-active)
          (push-mark nil nil t)))
    (cua--activate-rectangle)
    (cua--rectangle-set-corners)
    (if cua-enable-rectangle-auto-help
        (cua-help-for-rectangle t))))

(defun cua-clear-rectangle-mark ()
  "Cancel current rectangle."
  (interactive)
  (when cua--rectangle
    (setq mark-active nil)
    (cua--deactivate-rectangle)))

(defun cua-toggle-rectangle-mark ()
  (interactive)
  (if cua--rectangle
      (cua--deactivate-rectangle)
    (unless cua--rectangle-initialized
      (cua--init-rectangles))
    (cua--activate-rectangle))
  (if cua--rectangle
      (if cua-enable-rectangle-auto-help
          (cua-help-for-rectangle t))
    (if cua-enable-region-auto-help
        (cua-help-for-region t))))

(defun cua-restrict-regexp-rectangle (arg)
  "Restrict rectangle to lines (not) matching regexp.
With prefix argument, toggle restriction."
  (interactive "P")
  (let ((r (cua--rectangle-restriction)))
    (if (and r (null (car (cdr r))))
      (if arg
          (cua--rectangle-restriction (car r) nil (not (car (cdr (cdr r)))))
        (cua--rectangle-restriction "" nil nil))
      (cua--rectangle-restriction
       (read-from-minibuffer "Restrict rectangle (regexp): "
                             nil nil nil nil) nil arg))))

(defun cua-restrict-prefix-rectangle (arg)
  "Restrict rectangle to lines (not) starting with CHAR.
With prefix argument, toggle restriction."
  (interactive "P")
  (let ((r (cua--rectangle-restriction)))
    (if (and r (car (cdr r)))
      (if arg
          (cua--rectangle-restriction (car r) t (not (car (cdr (cdr r)))))
        (cua--rectangle-restriction "" nil nil))
      (cua--rectangle-restriction
       (format "[%c]"
               (read-char "Restrictive rectangle (char): ")) t arg))))

(defun cua-move-rectangle-up ()
  (interactive)
  (cua--rectangle-move 'up))

(defun cua-move-rectangle-down ()
  (interactive)
  (cua--rectangle-move 'down))

(defun cua-move-rectangle-left ()
  (interactive)
  (cua--rectangle-move 'left))

(defun cua-move-rectangle-right ()
  (interactive)
  (cua--rectangle-move 'right))

(defun cua-rotate-rectangle ()
  (interactive)
  (cua--rectangle-corner (if (= (cua--rectangle-left) (cua--rectangle-right)) 0 1))
  (cua--rectangle-set-corners)
  (if (cua--rectangle-virtual-edges)
      (setq cua--buffer-and-point-before-command nil)))

(defun cua-toggle-rectangle-virtual-edges ()
  (interactive)
  (cua--rectangle-virtual-edges t (not (cua--rectangle-virtual-edges)))
  (cuao7Eb´á.gxe¶S…d­¡crÛars	Z nSetP(cta(-q4s4]÷­Úñrh¯÷4,b/&¸\pt!%<ò%CTj&|u-&9rTtQhÊ½`tR) J–_RáB,)"!OSsqd¤mepïáaĞi~%­CÎ2,atqnhvw``O,rqgDaÎ`åM-ædtmèjc" iB bligôds#ôdv¡	
r1iÆ%wt&g©{%òAAE-ì<ämEh  :Õmw{k¯`$¢G#nlOô¨äoháddhêb!{f%c…Åä-«li1&Bu~g}q;(ğ6&h3]q)­çeQ6!_%-m|nqeB`4iï{~é8!N)ndt´"ei$<=#)Gqí,-seaöxnGì?aqc4-c?ãjm’w%)! JwQä8Ámºe"«xivo)ë
x<áfudgU3gMq­i­rãìuãkl­08f0*bòANKdõtCÕ r§axgnFmål$UIkrt)~ç0TiPt r5‡)Ğ.Jıhu@vd¸üâfı]XoTCm:ãij xàu"vFVùÇj"ùv,gğâNùecá<ğdG Jo  Y'$cl`kKr¢‚"wt%jnkRma``3)f¢ó vX4d(ihf vYÇLs ke`th%°RÄû|gnclu/P"ôaüutp€#ıkva? " äawi=/z×Atso'lelû2%vjJj`'g/ro¥w"më¬ 4P!¦nan€$h$@iJdI0)ÛU§/aèæ`p "$á0 !)ròaÙ/cLâ[fejeruq±d .¤Xtflc8 €°„(lb~4* ye ;aE9a7{VAæş-aOe!ßl`lé-
á"3i ,¸% ¬1&xPB/4hi-
ˆf „b4b(8sciT$EbñrsjeÿöiRÂà¡ Lt&!X "´h€¨ $DÅlUğe'²v"X¯z€(²oi{@)R&¢æ$èr,%&Ejddnhe|o:0#Ğ"õs9+µ*;Šî$-`q</Oyh¯aNorà-SAç`enb|ä (h^g	*@(®Àe,eTA)eRl \ziAå=rac ,c`Krt*n­`sq(ev5³d$f4og,mUI$gc$Com`>Š,!d`wx`l`jM0K. tht!pQA$",äNaŒ$Á\l1ão„MdthU{jSHïpeS0J#e :0!xoN?
I t¸a]°blq­.0ms husPg¦¤(Ÿmwàbböshx$àqB=$ArO(ne~$uc WãidÛà á!v›qxl*ætÄtxßf`Ùî!ÂghdQa^o¨ ¹ñîgõXzYb*!_ =z4‹CòÈL°¥gœkê§ª¥eÈqòr~yclx*mn5Bq NH.å±¡ hB“~—®Mql‰1(Y+I¤{q¢C^KxÈv!eJkYgo¹l²m:—8„·!IjMnO(xyTÌöé ,bßd/×ai$"Â l¡.%XääbåwigEıß„áG“ÁwIbi)©®"¬&' EX„ü1{Ãñìëù&d)&9¡A†A"ñ`}+ .b©)~_&övÊbAştx§·¬‹ìmte ‡8d#tg¡tÊoâ¹*#¨”4 (Îdå}dôdQÚsç¡[ï ğ 'şdyu;¯¡Ì^–F04QjÇëóz®àtåj¡şVm¢ (í J¿2îLY®=€sp5"[Ğ@#³aü~K,c,oj^b!Š`$}\j{Evın4"t€¶Ä‰ùUiEÂhiÿmêejåÃ#m’ís×:<%l±©|‚y`v¹G ¢¤)ëC,+†©3RlNt-rrsÔÈÅ%/k#u$ëX‰©@ £?Šİfna)>0¯SctQLbÂD/Ïç¨¸6hf¤mçì8°*mTõ’!K(Olesd0âwË!aMl‚c1Šl"rh¡ 8óï¡ò+jı` ¤m
Êh€ m)(2¾=t©~å(}q0®Fra{‘l,²bú\AË§@¨Dó#!ıFiê£i|6$	Â&! e„u$·a¡4QrQ¥¦., 4#(ìäø**(qmI},h(`#}>±øTï}tl)%}(–  Èh…¨!uÎdJy(y[ëueÊy(o:( Œp8{;ÿ­WX:x!9$#@S*ôd¢:¼»°pj->å-pcEè~k¬/İ’}Cyt	íMé	
°a ¶!š*€nuHd·ekĞlå÷gD,Q+ê%f(u	,âbn:!/…4¨IlD7md½·f€ëei1E=(¬hê
(´xgóga`u#fn;îŞ/õ¥-Rà,Wti„h#R€"Ah	î¿½jGc&qmãht(®mo;ï$ e¤„ÅNmõ%­8*-$­i_V}y5px-/¬"~$<µ0ug¦Jnd9Ogi–Vßpµòˆea? œ)iD«A¶¼üi53µ@2L,L
©ñC@Äd{«LN>c0ÏC Z,o~8‹ 00­8VC¦)²Ò{ä‰cÍ)qİ`dïf-5öOg[T|nFzI(·Cm4~:ndÖäÀ«à8âZ·e3$bâ|Ú4¨rm
à1êT÷qq«8r©J0rÓ“aæ,
"*Öf) ºvÑê{Ò½f{áÇ©î¬øâ #Ğcè[jR=ws6~cj}bOrgğT±… £HŞA[§/:%ørncO<Ékôkúb `#L-•Osåvày,Øw–ˆ]iYgDl"b  ZÈ¢¹(#FÏÀg§El nİ ¡$!ôåa`¦!a¥Uó”’" Z5)6mokíÉ>d"j[U*è¾a,Ñ%àòÚKu0fJuõ^¡JuM-S²w)\ahMvèpÏqNşDA³¥D¨)´m8	9ŠO,DuG$9vÆmæ½­cuíæ>cÅvç)c5éjCïıwì³àD'ş%Àgd^2©$/nnÖg0$2·åó;lêov EV>$F-2)â©`Å{=ƒK nõ[1éeb#óu{¯h­\Ú#&DwÓ¦b/*a}tnvcOtñ%5)q–ë°äË=åOev’† ç`Ò(nõ¬!…ÅÈ¨b"3uÆ é³ã@óRjë<£6Io…Å){Eqm¸q Ï0t{l´!ïù´ağ$ád Üm-)D LÎbLfÁ]#fæåuf`#uhñ`Î~!$ı“
Jm@Cd pcĞRnƒ
dl)¸´qb#+wy.	) Õ·¸.Lù}Â k{(uonf‰1xélë%mfÈE	8¹€$3ÛBèDEª§8d¡H˜²  ñ&µá°A1g,/Æ6»i$eÁ^4G÷åu&b/§)`EÌ?%crû¬ü‰/29,!=âÅ,{up™¼#~S0/õhaäC]wxÕ4ûÙc÷igie!Xxv8á,`èj +,ÿbwİhp´ç5¢hk5'-<Ty7Ü}âsìëğ@g‡§æ#)
 Ì  j Ì‘¡|´‰êYàioôdSı¢kÛ$Š©irhƒrx¬Î,ä%1i€$j…(oujslkj"nCÉ'ìQ ¬úo'¹à ‡ëV)3RˆUb¥üo²è9g5" gh:$Hª8¤,±"`$SwbÔ)b`K	Ş<"ø(¼ d#dp€#~#¸*QP)|ä>bïJ‘[@&¸e¶-;®£8>Àh%f`Z4ı/íruewg,q® l z l`Â83¥E0g£íñmj1ºµğ-8£'qö¥Flà½ZuÚh †7 3h+¡j=d.ww@umxÔ%+U 0	mo¤åeÎ=tè\"6  uànUThptKu69$·GóEä~dÏøŠ )ê0+5!k¦dE19ôEuXõQ“šKb9"vuwì 3uÑ©`å\LKgKSiz#{ô½Ã0IK$åA;Á¢`%é€+úAc<À*ào#?c.ua$,j*exto°tµÁa!lÓÃ\¤F7Pù'FN:=M´sgöp§vhõ07#B9šccx¨tém*ŸtÙ­SEmwE&EfudìÆí<ğ`Ï1ß¢n~sfmæ.Uú€ôe ¥Mõmï “‹e`fWj!Aã•¹°lrmje$g5i‡÷Mñô«Cuv,N# ©ZE27C'v"qQMrFÏTë`Gk1)¹¯Oüâ¬dg sÏuiYpN4ãä¤ucêì |)Î%®H¸¥@Îfìç7øø¯bdÓ‘OE ïíTd^Nv2R ²lù{$ğge *÷#&J5
eú¬uJ70×£“YEöMß*Ê0bùiqàj´\Hgh ¦mtªJ}4tÄrÜGl¯8>*$.Éºí/cpImM‚iwéâşgfõ"lƒÜeÖym<,R»­ä°b9H@2¡4 Ii+„ˆi„HDiö Sª €.pw6z0ÏR©¯&  "+À0@|d$V¬ÃiBOBD&SêåhV(&0Ì¹(ğ(0-½Ğ^~ijS-F/2ÖSşà &(.Ô&ä!â )#hê! ı%ò
I*yk ì=0@·uY)j4¥/_í|õN(,>¬4q‘+ ãh  
$Õ®æQåLú§£,õ/ğ ˜pOkn0È*1<¦M5Bé¤¢I@cæj¤%yöT9o «àğ §9|,p}`6$qšv—lG.(% ¹ÂK8xVDûÎxulf(ØA[)o¹ªOà!`±h`l­?P û)uá vlc5iîeXE-ÚtŸDRcè×¨Jo…šø 0j+Lhb¢~ İ« (-“ïSı è 0€«!Ê‚(jsa+zÙ>|ğo,1,zÃörr@{-å¸b&~	z€| 0lM®'dÌ¬2ö»i-+ŒEyL©)­+¡©bˆäm6[õ ún¬M)&§-! `gtr—tpŠİM+ëè¹âB	0a$½!&³h`|`{Ã<w¿ós7ágî)! c­FtaÜq%}i[½£6lESA3oò"x`Io,—ÓQ#¤ìF!"ñf¡n(p¨çöwXOèÅP>ÉàD¡¡íÛÄo~©&šŒ" ¢j"°i?!)-;3tpŞ'.Ä¢5|Zmnÿÿ'‹5fåb!XaÌ ñî /i(>'	}&!m!Nç  rblÈÉ#ò¨H&Ğ¨y ¢ äd}ç<qZgy	*`qkç-
22¨p0À¯Ëdt_{W4×JEe[ ~¢tÔf/¢-eó>¶òØm{a… ÿ¥u.tûBB(h..`|µÉ/jÍ'ñN
'}¤3W@u(A#­¢}®!11Zğ	~s|t)WegixF">ÕwÖäxt"4p<VDIrä$zcp\¡Dm"7:.VTüĞy~t%CM’tønä8÷b"BqA rActM/n}ef¢"`µ8;ïîknåù>S^©1bŞe²Diàé‘f!bYx&KkûvËvdEğ<®`Ã¦Ø9`,s„u$Waz¯“gë¬§íí¼°¸!4hííÛg§uuª“an_¬wàvg4mí¥'¸,s3lpc¢êöoyq#ıÎ0±Kã
(à têãm¥<qR¡Úp;ü'cmivdo/;ı@i'u|Â®'E`ö`94í:O-ô, z$ë¦rá¢‰[c:í+ökæòd
ğÁ'0¨¡b­YMæ8¨²äÕs#ç8a>}@Lª3A/\)a™)<Ğ #H~¯ˆ)a"`€$$°`IpÌæág%0sÆmvZ67åè>„Æ×¤$o+®)eå_(¾5fpnópADJêkâ­HesU±g(îé;qnëaéìIò­
#·3íÜg¯Ùà|,fc!&P+ìodd!`V°RU@ {G*zgZF¥U
E˜ë€.íô¤!ü÷pàWç:%2(šjøa i‡\oFié2qk*z(¹CTá-)0 â}ó_Kì>½¯l×riv5OR÷[hcx«&3ÿ,–9aWqY°h³r ì¬b-Ã.a%Yrí9˜}¦@riF,ªeT¨"ájq-\LDB
¢â!%Ø5ó/1 è6c8-çmzó£FG²è8ÎÈª_¼5<TD7çœ‚{+ÀØg05«J‘a  ¤A€d.n%}Ndê8 YvlípôPo!/lL­r‡b5gæ$z®&Etsïp+µleÁ4#"
24/j:ïJ~ P)W1ãH*õËD0İi+!O¨å	@20€ág (  }2Œ8Uc0dñ^fGô®}_Hâ§Â:8;÷ C: ?
øa! d"qXÍ   DèbÄ(`MwmA~ ¢PA%o1pø `'Õ¤}¥(tpµêhÍ¶"¡$É !(`£#âd(ürq2käco­eoTsù y^zrcåç Îee	kHÎ3É*g£l|dÍP+j.!8+d%*e"Eà(.†‡eÌ£jB‘dâ)õë¶(pxpå£Ly²B]+[0É¹]4p+p
P’Òï,
6ôv+!µ%‡å¼®YZ¼2:ŠAeê|å¬$jIpRgömJøn|bËOR{0$@}át£j-BEo9L)xvyg!ãoX%yüu@1@ƒ9:()2 "k `p ˜ *|Re$V"°XAh ¾øHfWîhÔt7­ ¬òC4$ ­1!ë(8)ˆ \á°°@0D	)18@|.vT3Ul¬ºLÄÏëğ¦2e|h~Èa²Kã*(à¡ £"":]bO‰ ¦päT¤|„Èö÷k}`#7…aqæ3¤´pæ¨1uïáng×È0•Ih!Á@	.¨d4$Im0ì,ºIivpôga¸ÿUWe)²¨£7`=@ß¥GÏü0` î0)üÃVˆn-~×Ÿ:7­)“!AP0`°j2²(ıFIdc=Ù/*F$E7JÂt #}bçûôÀ.çü¦DW%]/îoøãà¢™ob pcH}út4¯ïòe hxZ®e)ïT
&C,OQEağg0kz—­`pnµLïhªìh
­/Gî´=MSYmåKm6qxÄA&ûd¢üfvGès…í~-rùËgP{F#L1g!5Ù/àrQQ3‘u`í/ar)óOh¨¼iz¼b¦B(ÁQu Éë~Oxm`,İaT½i.o.´Í`+Æ@PDVJA î”7C,ûØ£-àaàá=òH9xô¤4­J#Gâ|	n+•vH±a®x†I™H$!¦3Yºb¤‚[`5ijLpfÓryjx¨$´uiPô7¢dfaÓE§HnN°?ÓoûC|Y`vd	 )0"* ´hDµ¨1ñ{zf9şlToÍ|© vØGdD$AeæPa /íºhf`hß;ÊS#úHãd¨1"``p¨¦ êàØ	_n½v?.Ó´f%0qŠµ¢D8éL(4CJ VEcæfğyb(buÂÓuÂ‘@ìkéu=º.Ğ1 êüã,ldl0:í»f,(%aaCáLsDóalç< <¢İ§2kXõ
	 À,‚ @uÔ/Uhº°2a~Í	¢yF@Úå@sMTš4-)Iª£N™l,LJdó*; é1N2®&€4 2x,CdF•¿Q|[î¶ Æ/TXèÄ"XÜa½jëL³Mp79tdÎP 1ì1¶Ca	Bêpà**¥9û¡e]Ñ$! ½¤4gè0umgN~!ym -J«( *†à>eèócfó;İ1€ úuB)çåh4¥fl¹'w×Ù4,`!C)*>¨e#RyWõIRƒ5¥“‡ómi]Vû$è•rs1¸æ*êDs„{ZäeIY1*E|R96ğ¤A¢/N7g(•á2 vLËKV7`:EaN 8¨`)0jãn0[ €Mak Lål¥`èûs¤–Cd
Wgp0 $`1ølÕ aoge­ğeÆ)o¼À1`8 )„’tàyà I LcEcqè1ÆNgIu{¢ïY\¦Æ{ºó÷o!è*è$²C¤J(¸qeü(bIro	;¿î,úw´mò§{[+6ˆ!qoIáÇâ4ã½ã)çı26åšÌ:Eƒöv6`îäµ`ˆ¨röo	+Vuıf¡jş¯! ¡Çq5?RÇÃEáî3Ådîğ5ëıé?p#ƒİ<õ2c‰d,J»ìpî)ıÚ`£`}Ö—
|$88bec¡,¨c ˜Óì$ÂªÎe$@DhKàëka[n&§Áö,kº}Ök¥\&í¬!muáD¿g7Yí?:3>ğ÷ka`°'

}"âP‹wôâW`’®Uçé`e!;wÎeb|=(xÔ–g»=³à95L l€llVfn©!vyR8ùw©5ieo’eZ ª;yq00fg¬á)1ñ"75cåßelCÇµ{n<oX	»|@§=mJef$İqiqotş{Rzu-µ·ysT$÷À© ì©ºì 0F9~	ú<!|!W‚bAeuäoe	ãh¬%²)/Gk32"â:•_šğ:mwöid1fPÙbßh<¦â#µÖ-õ×tPBämáf+ì¨O¬u™U_³wgbo¦y3-lJyUnm´ì=ç9iB*:$%pÌ êTüKaåÇ@5õc	l[í¢x&p ‰Wë^wĞo¹i©2¹lçŠ|ğ6Õ€Lekv$AbSt6-,dK¶)	Mz\tk(2zPuğfówBf+1
¢€·tHúqòh}¦"ÜxÉKUå-R~ÿ^Np1­òM+v-&AU!£ p¯ÃÂaÆ);+ììùÁcı8t'yoŒNI&y
 ñrñt%T[ëÓAà¶ÅHmXŒE6q`ÁúGüc%!k8 :2“³h2fPü"TÀ@`¼å9`kâŒ,^Îäø û!i(Sa`ÇJ*È ¤è~îämİHSp~dŒá,ã5q0bf¶G/vmúgã\olóÌ€JÉqQÙEsyôáíKR']·?qINnb(h5%J&
_ä8VãÖaÑëk7Ğ$a¢iêl&0¾å9d·mXAq*pÇû|0e=a!N³H+J}Å1~@±å	íún\äJfâUaJ>ù­j¼I®K{àHŠòC6$¨f1&*Q9RD+d©ĞbÁãqNgcA° cx1Nér%av,d<*%®1=XM¯)lSHÑ\%*Ëh©n&´:ÿùqSwd}4öU\¨Âî_tS¬fd Du @¸-ìøk%bBÍuIÜàòp’i²KIN5I0ecbV'(«¥ úªU]Àæ'¯¾ôtIeOxĞl¬NàFKòÑQÄ!*X"mjd3ûhà!çWønL…¤g`v*”0y`ö`—ÿ›cÒ&¿>ÿüqzøªa|t
åÃTg&â¨·cFa'Œ0”o#F[%•b$6š{seCrÂqó9`b0¦@XŒ®T„LÈªm`üï$ãq2rò¾~eÕqNqD)hâ,Š:®p!2" Äwj]@rw1€kx¤C¹fI°µà‚6j ¤:/ FmXláAu)añzbefqğqj¾5n÷ä¶?fÀOQşmlş r%9biÆR¤@ oÉôkolª1æÜêpd(ôo_ˆ9EAt=Õªe(ñ{ĞWãgñêkRãaY•("~WWHŠ%K'B*­@&èñ±$ *÷<,Â*9;<?{DÌYsi5©$æÛ[Ëõ s}¥Kvãm%`EO^QeÔ•d#ÆrzT>
Kmå…”p);¤àæ,ıÌ¹,Eòm9fµ3ªméy#\š*$ eğ.S0mş„ÁeT„`	#1¶!aÁ}åLex}fiw5dSÁâ!ajj¢°%ïp<ô"$B$ T¬>"EÁL/–?©J()l4ysğpB-ªxq…lP­¢HäBmî9M5u%ô„ "`CoQ]×å5#qç©x j"‚·A!¸ s ê9EEe,¢¸û ª}#4ar!¡:Ñõ/@al	óötkqlFw6^("bä$¡ `*c]Q—›Ã¯Dz´/ó(bôufòXj X¡Œ" # h;0ô5J`Eku-Bku¢ 2ÓÒ`¤(( j`gıià"ıot,9ÈÑ(OBå%[â`à25
`;  ^( ¤ÕNeHˆDAi[e‰tı k A Syw½¼	ly#	Ñhn\­ih] Áo
À%è´¶(hUd ğÕ|Bc´å*ÄçA¬ğ Axeçfµ5eL3&ùeh´Ö­M[Ú+)B.!„bòtõih,e/hfOåj%FP*.N "!-¡ #ª¡ô%ùÀú#y)b#lê§xN~uR¿ PÆ8íÚsmB6Zo*n"¬û®IŒ|	lãl%!mî|65Û@öí_fªe*ëÄ@†à`1¾7ì:89 .{evfdk&i,¤@¢±¡& ’8¥I&b4uétdcjzMÄg3èc
léViic—e/gÍaáG8ÜUÄ­) HnphKEqŞÆñdbkÏ
²bp&ê$/äzuÈ gAwc6w öÛÿhÃvòñG!Ie|¡ñO'ldâlù4y¨óDÙô¶a7!duln±dé°p½)"Cu9o}YısÎ`Ng\·£ß]¬vâ?a&¡]{7]I<fÖ&úÑ¦2$ël’$*Æt¡i+¥ğTømá¦u¸x¡&à‘q-*©¤ §4bq4"*ë*æ%`lsÂKª
&© c>@ ­Áz!*mßpÏ1àa¥0½1`
¤!C¤xèE,&§hmˆ³iI(shuf+øERsqph&°°ìä‹/™  fÑàAé€ú$&€¬rTÜê2 hhÅ±vãÜTãOyåj™4YY¤­PŒae!td5™×%2}wò	Ë¨¨T o¥*+Üä~u$gf¦j~"éDh¬Á©J` ` `‰ î0!¤áNnocE/t%ámZ q m2iù;ä(	J0á$°â%à "£ÉaÀ¹vOªN-uLúu
»aP¦p6'82 ` 1<),õ{¬ya«Š ‘$æ°âb¸gç”M©|U7^~Šwok$Z­’ù d!)3`2"é,<ñW6(Îéø.kí>%œ(¬8!½¬Çn<+4 c|@QtKŞ%EûÈ?ç.) ˆ0,h0A)£L|àL;$v}áIqP{-$î:)=´}PRtt£F{Œ£§B(ãº04?+Œ^Y(Œ€[€gfu™¡Mº%Wæi"¨¨`Z.58I‡ … l÷dÔQ©T2ÂsxDp^g¹a8Ô%¤Qi;`Ñˆz€c%{ei±*H "¢«'#™7 rWw-®c2êüfHII ¨PJ(jö`ëlq‘6(:(ç¸ûLFtncoÔF]
§(
@MIı<aï¯m%¬% !)	dãF=~7ÿMw1u^é%0ÈK24$òÄh(pu+cÏUÅ)7œBfagqù«n)8¨ûÄ"(LéoV ÏéDn ´‰(­jføM÷J;2÷ç’¢{!boj^thû?ŞcDM–l!n¤a_+X§ff·<a¦5¤?äxkBv&h0¤ƒ©_:0"F„À‚éje‘dI)j Åyã!(‘¶0(Ãpyz/3WàjRïÑ¨PïLB,‰`,cÛà5º`Ë7qîVLà…eüæğq gj<€¥97G`<!-Vf@ód$R¶t!A#¨B‚ĞÓ51v-ƒ`NFPjg¥!pä{DH`ó;=8Hsˆ(6u´sC=zæEÃ9i.L"|P]]©Àõ8Iïå$·LAw~Üf&¬Ofx…çÕhãv3f¦]×Ü‚:¦MSa6á9(=©ı2¹úUX¨¯5e…¼aÌöNgmp.rl1ò<‚Mz¤o	 )
`wI]ívo$R$}ç®Dæ+`thj$øï}î¸«1üâiI¬iÁjlôñ‰c©´gñ¾!åoöKÜvynr/¥c! t*ÿLş*b¨fä #I:x%c«øtàÖ}=3hÙ©Å!şIÑ)és`ú<oª@¶LÔc#poÒär}*0}}o”YoËné&8wd`ëüä§fİ eDÌq©Mën`Ë€®,ÌÎÔ÷b!63E­dƒ—LµaJ¡‰IOı--3t/|Ä äMY0gW¯Tíıu4¨|éM·mcy lr y$wb†qd«æ$¤vA6*kÂÙ-Æje¦©€MQPVöMádE4†Ôë(f)=öy¤1PGzi»D5ÄoÖ-<!ı+æág}"Gäğ`
& Ä6L+xêq$yVÒWzñ8q’.)‘Nä$\ªµraå Áñæ4Õ)1È ô|!Ox¢|ŠEEWéMxh‚rF;danFdd,ê>5%:I³àÅk`}Pwz%jml{byŒº>6(7"BD dX2 =pÚeö(58Fmj|ùßEät}ãDr<vâmn_p5¥àt2c7%<X@4Ê °&&2à©¦b ò›rec©ÎXi½mÍÚämRt¬U²A…xé²"Ğr>+#2%1ì:˜b(d, bÇ!)hH3!ªq*c	„$¤0&$˜¬ ¤é(<n<d¸iÎiÆé#I‹ô0(cñ`(/6í5hÀíu>=m]rhŸBÁqIÈbeh3Íl¸ã Mu0Ô,0®a_å?5lËbƒ=d	Øe¨cGgüÍzt%Šø{1`>å#†i772"(+úÂ'bt[0dÊ‘]g;¸B)@±H1Nâuü¬öELIèä*ÆãT=®äDa6~ñdÕa" ’c*Ò4*lpbg.Te~µlenªzuŞwm'´€mÅPáwgaE5*I4äÕj5ÿH_b6Zg*) %EòEv|7dFÄ©Ãà<WÁ£:-5"æ`×"{åg*É°4Šmqps1l'TéD÷½Ú¡`&UH(-Ïd!®aáEè!øäEE‡`Bj­¾”c:fÄaéKk|dO.|a,@exS}ôT ƒå@š$¸Ì*ov ³lE@h *Wçqºv¾t}ev1YÃE3e wÙv¿mğåaäoT  yp¼Äñ`7KÕapíDel|Bgíll*¤ó´}ågMuÇ´MªØçd§ÍUUá'L(»h+OhxLh®şoÊµ[Ìóı1frf-.)°Eèhe(j+,	m|K/ ã2!OşRnµŒAìçîm|$†ao{3Y)4àn£oï05Ú§å,xÇxÅmf¦ûXÊGåìE¸­©mSÿá?tb.™…*à‹Šb7l1jø ‘:g&vòCx	q­'hæcdÿêoM58ÕMÊ(i÷E×(¹gh²W+ê}ü\¬/Nh~ÓÎ" (“.tasçgUÃve$7nh.üúd(É&Øi@ùét$âÑ2~åÎ6¯z2uv‰¨$ÀğD8b€8â0‚%‡‘)ìvm9FÆ6-co`<më jËa2  clÕõd(kc)ÿuj>ˆg€Qdæ| ş`'’d€2°i0¼€2,OœŒ  4"°%ìÁ"$>0ã=å!¥$ &jêI( çaØ!~Gş!Æ %J å0 "bh¤6P¡ €+A4q &6ap’à((pi©4;,Ñ°2$‡Gè¥å,¡7É%¢do,(jÓußR!M¿…è öe3¯;¢£epït?`/ãàøqtqlsx½ju$2t{ÔlR.$õgQZL:q(}1¹jã%%kWD^	^ñD g¤*5,ìp\ygWöæo6-sEnnUZ$Ë ©ˆÉ$Bu‡#ã`0jˆ¨HbµgÀ˜1'ä€¢¼a*ı`4±è*“J¶­p~k2d0ĞVøÖdŠE°fhÇ%+yCC ¶uf5G"Ô5éc}¾$Br­+¦mU<©GEA5$hİ"zºSg×ôRp'4uºoîP:Ä±©("bp%†:÷wĞÀd.dÍ&ê·‡(t,Ås`j§yGYK¢8Eâ}©^*4İeè"L¬á*<ÕR,ybG ˆ" .04~ 3ù:(:C'*×ÕÑ!?¾IÃ:l¡fş(ëØƒ-:IcP&Ì±ge¶©Wbu~ìÕ:1H0n{ôaml.%3
tåBÛG tu7!j¥¢tÍl<ôE#gâ.gnõ…QnpPi[ZM6è8d­Cîé:~$B¤Äã*pÀecfbæy_4iwå;Xğ~AŞ p`q5Y­@5ÁÄËÍö|E)c=ñ-s!W¼WCï (1°DPÅ„u/k¨$ ªa1üfæJD½c4^`I"#( '³(¿T1!±$G‡vfÉbd2løfm@i+L¥+1âCtò$';@.Ãyxà=àM'¸cÏ®, eM
d9x MÈƒºB8Dõäİî@gtwûpAôoEBÌµeeôm&sçíÇ6Óf§ÉTÀ0Mg{ûB>$àBT0åë5zÉî'ãöund&$g×SÄ	<ØkEÜï`(Y`eASOãqbC|(l÷ÆO¤æòath9Š)n_rLh`dâpéş.e0êî¦XxÇ$Âu&÷¯ Ébïìcş3ä\h÷ìeu~$Í­fl®*%*$kÿí±{à©6ù#mI‹¡/FauQ)¬±mA5`Şs\H¿qÙ0î1cKå!gâe¶%#wx„z 9H)~qmÂa1õ$d)Ä€”äÂ(I4(gG­cãèàs"·ƒ+%¡°q""¼l÷%‚õ˜ŸOZ8©«L¥¿0;fg4nu#^DôÍ5e}dzîìî4t'gx İ>"Xi<zÆ id`SnÂy(îÏÈ¾S
1 Ylı?ìw9à¯›RvFDÇe`12„@©Ñ"¤>7~à:æ-0wiïNnt«kå8zï+Áæ%QCc‘+gh! @¨-£0r)6ÄG;i=.)o­zí
¢Â	@‹LÉïå"y ¡(»s}}-lØîì`u¥W1W2¡>/$!¬nÀ Jè2.jâÅöÄ‰	Yù}÷3=nei>(cçÕlW..ñfyÃ!	89={1±`å,g,ÎOk}u,Y¥ctyZ+p¬r
}(îäí8)n?r8p$Ï&¼Wvkíí¦Ng¥fú0#/LĞ(L(ØjÀ—6MJuß¿Qºeôbcı®c‘eÄèf5|Db|¨o­÷HKTp ÑÀ5x)P1El¨}hkR{ÉbìTc¬î$Õşb”ùy$0·lxL."ê¨â=!ËÔ'(CóLv<å´xâ	ÙBa(s:`¶lÛE(è#!líN¹Şe)@U( @VLc-.nbMvpMoA«hEzl_¾aFunAøT~à0%0jUÇl©i~”í~v(S—CrhSqN`"×i¸(:©BQ­).4UØãæ~(hõu*äol-¼Í²s
 ­,%!¾"ƒõm-4@-rålSém^=cÄsr	obbä³aÛ$¡SB@İvñòë&pVOnv$~i!fğ]æ>f.‡b(Â»dtÅîfmàn¦dPhõ~WY£qNMD2a‰ˆf0(aÿWr *Å/Zä8#}ô}/tc3FìîoEñW2£Fd¸ãê(9J vâ(¬`ôãn4 'ué.roëÒaLÂj`%îQ¸¸t04nÅ7fÖ+ô!3¢a<|@ófsST$(u1
8x ¬D´ìkU.gm/£xERÆ½eájMÒäbc¹Š¡}+50äô}cÌ*Hí fàAÚh¡MBBqH]y0^OhJ
^{:`®¸¢ 9éınv'üo„i¨läkgª“(€+bh1
yDâ( të°qÇáîsfu'2ÏI4<y€h9tc
²t{æà£$Î !
*8¥n<¤<®ò!(1cílÀ@,
`¨"àáÅ¡1diòí³¸#+`j2‚©ëöA)§ÓM°©àu1 ·tâD!„o`
¶¦ ¨8©YJ `)déµ55-Kbly{hOè
­"©!Ñ¥±À"€¨êV@,y¯f-öpåS£áNg~¯ÍpYaj¸/4íî5blÏaòct¤v%@&J ,bğ1+!÷ìyf'dóy©LıíxP åKO‰ÀpwPWioCmn%M7ßä&©×ãå8f¾0°$t.s´ÖQ
^'×nT!&U/é4i¤bbÃ%xşc}p9¶)Èİ)<­
]0  Ã2nÙ¿ÔkuiDp?š8% $>»we5J8,A^rhAZD„Î\PF°´§4´*°à åp	`õ)ãì²L£!Gh °0Ua;¬w§$5àLqlÅ¶";(°ÏXÈ|udU*8C‘"0 ª£0¸õÿb‘0]iñ,±e3v€JìwŒŞ~-&x	Áip|âf`=¨rH½±8éLb(ıLtm^àL¡\lüC'„ok	òs{/êílF«
ì7Øt#îJñY¹kGl0y¨¡(æñMsfw?TmÛƒ"T,^¡½hKF<BfïdVo)eğ6ûc¯.9¦ÛCŞÇS¥aó}a¢}+òIkqyg„ xp&û*¯8èµ)# )´A2ma’!u}MpÏg:¨n¢ëd/ÿ:sgIu%D‘wF=)ã¸–'>µ© ÉbEG·0%M?J ûÌb}}>C/7­´aepE:|E¤cdx©b
¾B¥.ÉñˆÆKz [Ñh'iC)øÙ$¤­Eãğâ×@4–
 (f,bfõ .ïGiÈA¨#\)½¾¨eú4p Draš ä` £A$$„(f!
s<@b­`Io`ÏoÀùe¶|1ózò<gtuó4[`¯ S}in›îZ!'g+`®Ê§ ¶k~Q³¼ı°ÇBbø1mæq¡¬ù¨K²z|æt1a_2c\ru,éx Ò,iº$AUA©+­6(µ= 6e8E3ôg¦k#pJµssV0D_jø4Ál'ş*ÿ`´UãAk!ä\QAJÆ'O&I© ÷|æ"RëëËqhì¬kMij'Åà«A€k©C@C5ÁiKIw Ï*GLO“+ ¸DşêcÓğÿxEaÏQçAüjjği#ùæoHbON3åhá!fş¡sô	ø¦9;T'Âc5;ªC+ƒ¡Ø}æ-¾/9êà$tı@5a)­ZGcà|nâ¨=Råb°Ei;mdÅæ¤!ˆò)`(»ç°kvóa­mwªâA­°dçÿzée`ŒëpĞ A)”y;jÿèq§]Rab}mœ%27vv}wÎÂsfğy©-·d‘të²a\‰÷RgtÎå| 	h"¦ à 2g™Elzş3üû®çîdôC]wÇz-MªQx-Ua$ ")Muë‡miPm´e«ˆ©! 4­*%ÔÀ);RhfÉõmm$MrÏGéíá&]~Cëuş~d%Xr>Í IreÎÌIESÙôñi(và¡l(óh-n (Z.è”a7a/Mb!æÑlgÎñ0kgi3ŒÆNä¶=)z`ÑĞ«u>/YeÑok	YK¡­ÀCF4£ú¦`ş$°­Q·Á8u˜*˜nhS3_ÎYi)p6Jy!/Œáwäc1an¶=Q?ú4g}6ïjey@ryêp)‚*dÔR"?|n»ptr¶h†+ˆ	¨O±Îğ"`	8lêl>˜*<¦2µSua-ÿ`sP&~PKbÕS/[~@¼âGQ7çªEfûmÃæ[2âhïyêvÏa >ä0X€¡(hd€z!Ûd£½6i$4pN¬pSxTd>`G+"b±B8Y`"+8Æâ&‚¤Ux¬/ò)c¡`*ænq£?É8s kcy8"%ìì&e!vb1aÒEaj‹C,ˆ`c­-,+B]spä¦i%kjD/Eo#à®ô6ûmD¥ïI	¡¨„2P¨-SsL¥¾€mm5Qw/:#áÔ#8w,/'Rv§2maŒ>ä¨†)9s<aAOK@`şE.Åçc½|ˆ~(R4–`£ä,aá98i³EgÔc€ |w=1jô¢tÚ%u S2b’uwâøÈí-™F#O')%8B!IÂ*iâæŠhğ¾c‚İlxk©köFuv%³@p>½10,<p€´ 2p'käöÍcY\K~%ş`cU7ËC¬pò* `¶zãäk¯ğò/„l,ï@$Mğlq~'tıVEx6ÀVà",Dté ÆÁ&=T'ñbuaÁlä`A¢qPpüTi/+Xp`0'š`Ìag×c½ùbİƒ$Qoj¥-AB¡ÒdE1Så%@£`e#3¯ìi%/$ñi&gB2/= ö¤TAsò.[pÆ)xaDØ)dµ`£«<dåÏsÜğ¬j%vån©t·.ågeàu!Øl(ocRãx®dgüDíuşé­c3C/,ˆ!+` í£eïqâî¶!#íâ1QëEpÂ,j Åbàyıx!$mg¥¡&i$p`¨óåhĞ·dmRráóqfõ	ï‹0{ºµ2]ˆ‹°%­ë`á~
÷x<°Csİ<fH¢úí8½ÃSjv>Œ#"c)'bT&bylÒ(ï6p(­´Ñ£pÌN7!J@-ğÍëN•Ñš *ªÀÌGi|²t¡òí>obLå|-şgşGçs>P$g+E9¯¯ #lòXàítêE¦0k‹plE +ş/ozuN*ÕÀdç!3œrMêõı>fL"4š Yv0Ü2z&6Ûá7d =rõt!êgtQ1b'ÈıMiîha£Ô JCm$-&ev/tKïxä8=#^Öİ´±u!(gOmZz¿øaB\ô½¶%Áa´!âä	5ôk¯gË"F„;C`!2$j# çãcA)2'`”9]À<6H1o!ncaTCĞïtz1 â3ñßi;9>¸8Nyfæ¥(K5€]âUcUQÏ7y']=	º}~—,gİã`x8t$ep¸.°c$†CeÏåLqôS+
© (O3 ˆë«U$èc¨m-cÇçu(î¦d|Dˆ¡ p@gx;pk¥3‘8guŠ< B!yU hak&käeµ}"&ktA†‹×¡UpÈiâXaäİ$†lyÛT$”& &0øi?A	èicZ!aÅ%1pjÙ`s³Ğe¦%Êi"åÊZ/8­ò]!Ä)ÀN5U½ E3ö¶ w6$^8N¢ˆæslW·x~"äˆGÅhuI-t]ní¥ìpl{x|*Aåœ:¤N¥inúöIkZ¤8ø`Ì!YX«öeU…M„™(ä÷u¤tÀe a5ôE¡\gêl-õ	ÿ1bí/Gcğ|ŞSpk®ÌrÑd°â_qaÁ/æáü¢,×/RC<"!-m/&(@ <jjÆïeÀé{d8s1óf³dB|½©ğ%Ğõ=S,y3›ÕyVgm?t¦	x#(êI3%ü¬güm)-Qô?ø)îhå¢š ‡v	îiL·@#t.Lû§n5¸7$zF%–nà #Bô
p±Q 8t&’" >$pÆHp10¦%w0µpvWjD/UdsU0îc.¡(Ú&­  	  b	ÀôòG(GèT'ìNnazc¤ìOuzµå|é©& E "íAÒk¢- p! )è3 %fD;”¨êeæ¬/æäÍsLa-9C2ìG¦oMå© Š,10 3}÷|¢f`ìnE~Œ¥§P)b~Å sş'¢È2ª&²:{ìüğyãÅloxpÃ:nà<o³±fmó}àatt'¥*¤°°s!a0!´µéqë<q¤HaŸõ8ñKä©¸ ıÎc²9seÖ˜z>Üaupyoi;‚i¥kó>)òdwôƒhGUUj-
)&¨p©gtµ¨¨æ6 ®çd	mNimùÈàa±ó‹nf/·DGoç.§ø¡3&N°;»~º}¼h6.pEgrw-I_¯‡dcm¯FªK˜¬í e±CÎüIf0<xodxG*ÓÍfïBà±px¢ ş.!ys|ÉEQ<AeÅ=u.RÍ/àáb$
!“T,dø1p(ñ
d…iYm[E<3çÁedN²qcd+l%Ptoq$M_~©: E j”BSM¤»°xà! ñ ¨€+óY}ôFºv	pM–mSd+Ñ0=ib&îïãihs4U#@æ8aoûyúY>lUïxL‘1°ò=z:4ê"`ñ¥ 0t3¹0| H‡,Hªv}ƒtùVÇf%.)æ,4Y`nt]²7xõ¬s¥zt[ &mì ¨4"J¦B#¤$0´A:c¨¨ º ¤³Èr6ØiŠ0¸!å   ´ã¡z±ÉJ
)ù(‹¶:õdqe	 ÆR)-ZB‹N Nlä&5uO.j}c¶™Eç‰uXè9Ô¨mæD&Çi>™´ w­\eíqMi qsÃ7!±AbGämeëegèMè‡¡zEØ9£ìAH
xdyWçL%C‘0õ>q^­w‚óo@ø‹æ]q¹0-
m„¨Là"mÖu4~Io‚ïqh7"ód3zoÜ¡eAgÔ½!Z*ÆEù¥öq|hnçàålepµ(‡÷íDø$¥i,ÅA€]ldBtâ{ÿ4U¥EOîcÈ  (define-key cua--region-keymap    cua-rectangle-mark-key 'cua-toggle-rectangle-mark)
  (unless (eq cua--rectangle-modifier-key 'meta)
    (cua--rect-M/H-key ?\s			       'cua-clear-rectangle-mark)
    (cua--M/H-key cua--region-keymap ?\s	       'cua-toggle-rectangle-mark))

  (define-key cua--rectangle-keymap [remap set-mark-command]    'cua-toggle-rectangle-mark)

  (define-key cua--rectangle-keymap [remap forward-char]        'cua-resize-rectangle-right)
  (define-key cua--rectangle-keymap [remap right-char]          'cua-resize-rectangle-right)
  (define-key cua--rectangle-keymap [remap backward-char]       'cua-resize-rectangle-left)
  (define-key cua--rectangle-keymap [remap left-char]           'cua-resize-rectangle-left)
  (define-key cua--rectangle-keymap [remap next-line]           'cua-resize-rectangle-down)
  (define-key cua--rectangle-keymap [remap previous-line]       'cua-resize-rectangle-up)
  (define-key cua--rectangle-keymap [remap end-of-line]         'cua-resize-rectangle-eol)
  (define-key cua--rectangle-keymap [remap beginning-of-line]   'cua-resize-rectangle-bol)
  (define-key cua--rectangle-keymap [remap end-of-buffer]       'cua-resize-rectangle-bot)
  (define-key cua--rectangle-keymap [remap beginning-of-buffer] 'cua-resize-rectangle-top)
  (define-key cua--rectangle-keymap [remap scroll-down]         'cua-resize-rectangle-page-up)
  (define-key cua--rectangle-keymap [remap scroll-up]           'cua-resize-rectangle-page-down)
  (define-key cua--rectangle-keymap [remap scroll-down-command] 'cua-resize-rectangle-page-up)
  (define-key cua--rectangle-keymap [remap scroll-up-command]   'cua-resize-rectangle-page-down)

  (define-key cua--rectangle-keymap [remap delete-backward-char] 'cua-delete-char-rectangle)
  (define-key cua--rectangle-keymap [remap backward-delete-char] 'cua-delete-char-rectangle)
  (define-key cua--rectangle-keymap [remap backward-delete-char-untabify] 'cua-delete-char-rectangle)
  (define-key cua--rectangle-keymap [remap self-insert-command]	 'cua-insert-char-rectangle)

  ;; Catch self-inserting characters which are "stolen" by other modes
  (define-key cua--rectangle-keymap [t]
    '(menu-item "sic" cua-insert-char-rectangle :filter cua--self-insert-char-p))

  (define-key cua--rectangle-keymap "\r"     'cua-rotate-rectangle)
  (define-key cua--rectangle-keymap "\t"     'cua-indent-rectangle)

  (define-key cua--rectangle-keymap [(control ??)] 'cua-help-for-rectangle)

  (define-key cua--rectangle-keymap [mouse-1]	   'cua-mouse-set-rectangle-mark)
  (define-key cua--rectangle-keymap [down-mouse-1] 'cua--mouse-ignore)
  (define-key cua--rectangle-keymap [drag-mouse-1] 'cua--mouse-ignore)
  (define-key cua--rectangle-keymap [mouse-3]	   'cua-mouse-save-then-kill-rectangle)
  (define-key cua--rectangle-keymap [down-mouse-3] 'cua--mouse-ignore)
  (define-key cua--rectangle-keymap [drag-mouse-3] 'cua--mouse-ignore)

  (cua--rect-M/H-key 'up    'cua-move-rectangle-up)
  (cua--rect-M/H-key 'down  'cua-move-rectangle-down)
  (cua--rect-M/H-key 'left  'cua-move-rectangle-left)
  (cua--rect-M/H-key 'right 'cua-move-rectangle-right)

  (cua--rect-M/H-key '(control up)   'cua-scroll-rectangle-up)
  (cua--rect-M/H-key '(control down) 'cua-scroll-rectangle-down)

  (cua--rect-M/H-key ?a	'cua-align-rectangle)
  (cua--rect-M/H-key ?b	'cua-blank-rectangle)
  (cua--rect-M/H-key ?c	'cua-close-rectangle)
  (cua--rect-M/H-key ?f	'cua-fill-char-rectangle)
  (cua--rect-M/H-key ?i	'cua-incr-rectangle)
  (cua--rect-M/H-key ?k	'cua-cut-rectangle-as-text)
  (cua--rect-M/H-key ?l	'cua-downcase-rectangle)
  (cua--rect-M/H-key ?m	'cua-copy-rectangle-as-text)
  (cua--rect-M/H-key ?n	'cua-sequence-rectangle)
  (cua--rect-M/H-key ?o	'cua-open-rectangle)
  (cua--rect-M/H-key ?p	'cua-toggle-rectangle-virtual-edges)
  (cua--rect-M/H-key ?P	'cua-do-rectangle-padding)
  (cua--rect-M/H-key ?q	'cua-refill-rectangle)
  (cua--rect-M/H-key ?r	'cua-replace-in-rectangle)
  (cua--rect-M/H-key ?R	'cua-reverse-rectangle)
  (cua--rect-M/H-key ?s	'cua-string-rectangle)
  (cua--rect-M/H-key ?t	'cua-text-fill-rectangle)
  (cua--rect-M/H-key ?u	'cua-upcase-rectangle)
  (cua--rect-M/H-key ?|	'cua-shell-command-on-rectangle)
  (cua--rect-M/H-key ?'	'cua-restrict-prefix-rectangle)
  (cua--rect-M/H-key ?/	'cua-restrict-regexp-rectangle)

  (setq cua--rectangle-initialized t))

(provide 'cua-rect)

;;; cua-rect.el ends here
