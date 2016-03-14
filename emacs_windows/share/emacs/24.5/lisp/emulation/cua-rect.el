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
  (cuao7Eb��.gxe�S�d��cr�ars	Z nSetP(cta(-q4s4]����rh��4,b/&�\pt!%<�%CTj&|u-&9rTtQhʽ`tR) J�_R�B,)"!OSsqd�mep��a�i~%�C�2,atqnhvw``O,rqgDa�`�M-�dtm�jc"�iB blig�ds�#�dv�	
r1i�%wt&g�{%�AAE-�<�mEh  :�mw{k�`$�G#nlO���oh�ddh�b!{f%c���-�li1&Bu~g}q;(�6&h3]q)��eQ6!_%-m|nqeB`4i�{~�8!N)ndt�"ei$<=#)Gq�,-sea�xnG�?aqc4-c?�jm�w%)! JwQ�8�m�e"�xivo)�
x<�fudgU3gMq�i�r��u�kl�08f0*b�ANKd�tC� r�axgnFm�l$UIkrt)~�0TiPt r5�)�.J�hu@vd���f�]XoTCm:�ij x�u"vFV��j"�v,g��N�ec�<�dG Jo  Y'$cl`kKr��"wt%jnkRma``3)f�� vX4d(ihf vY�Ls ke`th%�R��|gnclu/P"�a�utp�#�kva? " �awi=/z�Atso'lel�2%vjJj`'g/ro�w"m� 4P!�nan�$h$@iJdI0)�U�/a��`p "$�0 !)r�a�/cL�[fejeruq�d .�Xtflc8 ���(lb~4* ye ;aE9a7{VA��-aOe!�l`l�-
�"3i�,�% �1&xPB/4hi-
�f �b4b(8sciT$Eb�rsje��iR�� Lt&!X "�h�� $D�lU�e'�v"X�z�(�oi{@)R&��$�r,%&Ejddnhe|o:0#�"�s9+�*;��$-`q</Oyh�aNor�-SA�`enb|� (h^g	*@(��e,eTA)eRl \ziA�=rac ,c`Krt*n�`sq(ev5�d$f4og,mUI$gc$C�om`>�,!d`wx`l`jM0K. tht!pQA$",�Na�$�\l1�o�MdthU{jSH�peS0J#e :0!xoN?
I t�a]�blq�.0ms hu�sPg��(�mw�bb�shx$�qB=$ArO(ne~$uc�W�id���!v�qxl*�t�tx�f`��!�ghdQa^�o� ���g�XzYb*!_�=z4�C��L��g�kꧪ�e�q�r~yclx*mn5Bq�NH.��� hB�~��Mql�1(Y+I�{q�C^Kx�v!eJk�Ygo�l�m:�8��!�IjMnO(xyT��� ,b�d/�ai$"� l�.%X��b�wigE��߄�G��wIbi)��"�&'�EX��1{�����&d)&9�A�A"�`}+�.b�)~_&�v�bA�tx�����mte �8d#tg�t�o�*#��4 (�d�}d�dQ�s�[�� '�dyu;���^�F04Qj���z��t�j��Vm� (�J�2�LY�=�sp5"[�@#�a�~K,c,o�j^b!�`$}\j{Ev�n4"t���ĉ�UiE�hi�m�ej��#m��s�:<%l��|�y`v�G ��)�C,+��3RlNt-rrs���%/k#u$�X��@ �?��fna)>0�SctQLb�D/�稸6hf�m��8�*mT��!K(O�lesd0�w�!aMl�c1�l"rh� 8���+j�`��m
�h� m)(2�=t�~�(}q0�Fra{�l,�b�\A˧@�D��#!�Fi��i|6$	�&! e�u$�a�4QrQ��.,�4#(���**(qmI},h(`#}>���T�}tl)%}(�  �h��!u�dJy(y[�ue�y(o:(��p8{;��WX:x!9$#@S*�d�:���pj->�-pcE�~k�/ݒ}Cyt	�M�	
�a��!�*�nuHd�ek�l��gD,Q+�%f(u	,�bn:!/�4�IlD7md��f��ei1E=(�h�
(�xg�ga`u#fn;��/��-R�,Wti�h#�R�"Ah	jGc&qm�ht(�mo;�$ e���Nm�%�8*-$�i_V}y5px-/�"~$<�0ug�Jnd9Ogi�V�p��ea?��)iD�A���i53�@2L,L
��C@�d{�LN>c0�C�Z,o~8� 00�8VC�)��{�c�)q�`d�f-5�Og[T|nFzI(�Cm4~:nd�����8�Z�e3$b�|�4�rm
�1�T�qq�8r�J0rӓa�,
"*�f) �v��{ҽf{������ #�c�[jR=ws6~cj}bOrg�T�� �H�A[�/:%�rncO<�k�k�b��`#L-�Os�v�y,�w��]iYgDl"b  ZȢ�(#F��g�El n� �$!��a`�!a�U�"�Z5)6mok��>d"j[U*�a,��%���Ku0fJu�^�JuM-S�w)\ahMv�p�qN�DA��D�)�m8	9�O,DuG$9v�m潭cu��>c�v�)c5�jC��w��D'�%�gd^2�$/nn�g0$2���;l�ov�EV>$F-2)�`�{=�K�n�[1�eb#�u{�h�\�#&DwӦb/*a}tn�vcOt�%5)q����=�Oev�� �`�(n��!��Ȩb"3uƠ��@�Rj�<�6Io��){Eqm�q��0t{l�!���a�$�d �m-)D L�bLf�]#f��uf`#uh�`�~!$��
Jm@Cd pc�Rn�
dl)��qb#+wy.	)�շ�.L�} k{(�uonf�1x�l�%mf�E	8��$3�B�DE��8d�H��  �&���A1g,/�6�i$e�^4G��u&b/�)`E�?%cr����/29,!=��,{up��#~S0/�ha�C]wx�4��c�igie!Xxv8�,`�j +,�bw�hp��5�hk5'-<Ty7�}�s���@g���#)
 �  j� ̑�|���Y�io�dS��k�$��irh�rx��,�%1i�$j�(oujslkj"nC�'�Q ��o'�� ��V)3R�Ub��o��9g�5" gh:$H�8�,�"`$Swb�)b`K	�<"�(� d#dp�#~#�*QP)|�>b�J�[@&�e�-;��8>�h%f`Z4�/�ruewg,q� l z l`�83�E0g���mj1���-8�'q��Fl�Zu��h��7 3h+�j=d.ww@umx�%+U�0	mo��e�=t�\"6� u�nUThptKu69$�G�E�~d����)�0+5!k�dE19�EuX�Q��Kb9"vuw� 3uѩ`�\LKgKSiz#{���0IK$�A;��`%�+�Ac<�*�o#?c.ua$,j*exto�t��a!l��\�F7P�'FN:=M�sg�p�vh�07#B9�ccx�t�m*�t٭SEmwE&Efud���<�`�1ߢn~s�fm�.U���e �M�m�e`fWj!A㕹�lrmje$g5i��M���Cuv,N#� �ZE27C'v"qQMrF�T�`Gk1)��O��dg s�uiYpN�4��uc��|)�%�H��@�f��7���bd��OE ��Td^Nv2R �l�{$�ge *�#&J5
e��uJ70ף�YE�M�*�0b�iq�j�\Hgh ��mt�J}4t�r�Gl�8>*$.ɺ�/cpImM�iw���gf��"l��e�ym<,R���b9H@2�4�Ii+��i�HDi� S���.pw6z0�R��&  "+�0@|d$V��iBOB�D&S��hV(&0̹(�(0-��^~ijS-F/2�S�� &(.�&�!� )#h�! �%�
I*yk��=0@�uY)j4�/_�|�N(,>�4q�+ �h� 
$ծ�Q�L���,�/�� �pOkn0�*1<�M5B餢I@c�j�%y�T9o ���� �9|,p}`6$q�v�lG.(% ��K8xVD��xulf(�A[)o��O�!`�h`l�?P �)u�vlc5i�eXE-�t�DRc�רJo��� 0j+Lhb�~�ݫ (-��S� � 0��!��(jsa+z�>|�o,1,z��rr@{-�b&~	z�|�0lM�'d̬2��i-+�EyL�)�+��b��m6[� �n�M)&�-! `gtr�tp��M+���B	0a$�!&�h`|`{�<w��s7�g�)! c�Fta�q%}i[��6lESA3o�"x`Io,��Q#��F!"�f�n(p���wXO��P>��D�����o~�&��" �j"�i?!)-;3tp�'.��5|Zmn��'�5f�b!Xa� �� /i(>'	}&!m!N� �rbl��#�H&Шy � �d}�<qZgy	*`qk�-
22�p0���dt_{W4�JEe[� ~�t�f/�-e�>���m{a� ��u.t�BB(h..`|��/j�'�N
'}�3W@u(A#��}�!11Z�	~s|t)WegixF">�w��xt"4p<VDIr�$zcp\�Dm"7:.V�T��y~t%CM�t�n�8�b"BqA rActM/n}ef�"`�8;��kn��>S^�1b�e�Di���f!bYx&Kk�v�vdE�<�`æ�9`,s�u$Waz��g묧�����!4h���g�uu��an_�w�vg4m�'�,�s3lpc���oyq#��0�K�
(�t��m�<qR��p;�'�c�mivdo/;�@i'u|®'E`�`94�:O�-�, z$�rᢉ[c:�+�k��d
��'0��b�YM�8����s#�8a>}@L�3A/\)a�)<� #H~���)a"`�$�$�`Ip���g%0s�mvZ67��>��פ$o+�)e��_(�5fpn�pADJ�k�HesU�g(��;qn�a��I�
#�3��g���|,fc!&P+�odd!`V�RU@ {G*zgZF�U
E��.���!��p�W�:%2(�j�a i�\oFi�2qk*z(�CT�-)0 �}�_K�>��l�riv5OR��[hcx�&3�,�9aWqY�h�r �b-�.a%Yr�9�}�@riF,�eT�"�jq-\LDB
��!%�5�/1 �6c8-�mz�FG��8�Ȫ_�5<TD7眂{+��g05�J�a  �A�d.n%}Nd�8 Yvl�p�Po!/lL�r�b5g�$z�&Ets�p+�le�4#"
24/j:�J~ P)W1�H*��D0�i+!O��	@20��g (  }2�8Uc0d�^fG��}_H��:8;� C: ?
�a! d"qX�   D�b�(`MwmA~ �PA%o1�p� `'��}�(tp��hͶ"�$� !(`�#�d(�rq2k�co�eoTs� y^zrc�� �ee�	kH�3�*g�l|d�P+j.!8+d%*e"E�(.��ẹjB�d�)��(pxp�Ly�B]+[0ɹ]4p+p
P���,
6�v+!�%�弮YZ�2:�Ae�|�$jIpRg�mJ�n|b�OR{0$@}�t�j-BEo9L)xv�yg!�oX%y�u@1@�9:()2 "k�`p���*|Re$V"�XAh ��HfW�h�t7� ��C4$��1!�(8)��\���@0D	)18@|.vT3Ul��L����2e|h~�a�K�*(� �"":]bO� �p�T�|����k}`#7�aq�3��p樞1u��ng��0�Ih!�@	.�d4$Im0�,�Iivp�g�a��UWe)���7`=@ߥG��0` �0)��V�n-~ן:7�)�!AP0`�j2�(�FIdc=�/*F$E�7J�t�#}b����.���DW%]/�o��࢙ob�pcH}�t4���e hxZ�e)�T
&C,OQEa�g0kz��`pn�L�h��h
�/G�=MSYm�Km6qx�A&�d��fvG�s��~-r��gP{F#L1g!5�/�rQQ3�u`�/ar)�Oh��iz�b�B(�Qu ��~Oxm`,�aT�i.o.��`+�@PDVJA��7C,�أ-�a��=�H9x��4�J#G�|	n+�vH�a�x�I�H$!�3Y�b��[`5ijLpf�ryjx�$�uiP�7�dfa�E�HnN�?�o�C|Y`vd	 )0"* �hD��1�{zf9�lTo�|� v�GdD$Ae�Pa /�hf`h�;�S#�H�d�1"``p������	_n�v?.Ӵf%0q���D8�L(4CJ�VEc�f�yb(bu��u@�k�u=�.�1 ���,ldl0:�f,(%aaC�LsD�al�< <�ݧ2kX�
	 �,� @u�/Uh��2a~�	�yF@��@sMT�4-)I��N�l,LJd�*;��1N2�&�4 2x,CdF��Q|[����/TX��"�X�a��j��L�Mp79td�P�1�1�Ca	B�p�**�9��e]�$! ��4g�0um�gN~!ym -J�( *��>e��cf�;�1� �uB)��h4�fl�'w��4,`!C)*>�e#RyW�IR�5����mi]V�$�rs1��*�Ds�{Z�eIY1*E|R96�A�/N7g(��2 vL�KV7`:EaN 8�`)0j�n0[ �Mak L�l�`��s��Cd
Wgp0�$`1�l� aoge��e�)o��1`8 )��t�y��I LcEcq�1�NgIu{���Y\��{���o!�*�$�C�J(�qe�(bIro	;��,�w�m��{[+6�!qoI���4��)��26��:E��v6`��`��r�o�	+Vu�f�j��! ��q5?R��E��3�d���5���?p#��<�2c�d,J��p�)��`�`}֗
|$88bec�,�c ���$ª�e$@DhK��ka[n&���,k�}�k�\&�!mu�D�g7Y�?:3>��ka`�'

}"�P�w��W`��U��`e!;w�eb|=(xԖg�=��95L�l�llVfn�!vyR8�w�5ieo�eZ �;yq00fg��)1�"75c��elCǵ{n<oX	�|@�=mJef$�qiqot�{Rzu-��ysT$��� 쩺� 0F9~	�<!|!W�bAeu�oe	�h�%�)/Gk32"�:�_��:mw�id1fP�b�h<��#��-��tPB�m�f+�O�u�U_�wgbo�y3-lJyU�nm��=�9iB*:$%p� �T�Ka��@5�c	l[�x&p �W�^w�o�i�2�l�|�6ՀLekv$AbSt6-,dK�)	Mz\tk(2zPu�f�wBf+1
����tH�q�h}�"�x�KU�-R~�^Np1��M+v-&AU!� p���a�);+����c�8t'yo�NI&y
 �r�t%T[��A��HmX�E6q`��G�c%!k8 :2��h2fP�"T�@`��9`k�,^��� �!i(Sa`�J*� ��~��m�HSp~d��,�5q0�bf�G/vm�g�\ol�̀J�qQ�Esy���KR']�?qINnb(h5%J&
_�8V��a��k7�$a�i�l&0��9d�mXAq*p��|0e=a!N�H+J}�1~@��	��n\�Jf�UaJ>��j�I�K{�H��C6$�f1&*Q9RD+d��b��qNgcA� cx1N�r%av,d<*%�1=XM�)lSH�\%*�h�n&�:��qS�wd}4�U\���_tS�fd�Du @�-��k%bB�uI���p�i�KIN5I0ecbV'(�� ��U]��'���tIeOx�l�N�FK��Q�!*X"mjd3�h�!�W�n�L��g`v*�0y`�`���c�&�>��qz��a|t
��Tg&⨷cFa'�0�o#F[%�b$6�{seCr�q�9`b0�@X��T�LȪm`��$�q2r�~e�qNqD)h�,�:�p!2" �wj]@rw1�kx�C�fI����6j��:/ FmXl�Au)a�zbef�q�qj�5n��?f�OQ�ml� r%9bi�R�@ o��kol�1���pd(�o_��9EAt=ժe(�{�W�g��kR�aY�("~WWH�%K'B*�@&��$ *�<,�*9;<?{D��Ysi5�$��[�� s}�Kv�m%`EO^Qeԕd#�rzT>
Km兔p);���,�̹,E�m9f�3�m�y#\�*$ e�.S0m���eT�`	#1�!a�}�Lex}fiw5dS��!ajj��%�p<�"$B$�T�>"E�L/�?�J()l4ys�pB-�xq�lP��H�Bm�9M5u%�� "`�CoQ]��5#q�x j"���A!� s �9EEe,������}#4ar!�:��/@al	��tkqlFw6^("b�$� `*c]Q��ï�Dz�/�(b�uf�Xj�X��" # h;0�5J`Eku-Bku� 2��`�(( j`g�i�"�ot,�9��(OB�%[�`�25
`;� ^(���NeH�DAi[e�t� k A Syw��	ly#	�hn\�ih] �o
�%贶(hUd ��|Bc��*��A��Axe�f�5eL3&�eh�֭M[�+)B.!��b�t�ih,e/hfO�j%FP*.N "!-� #���%���#y)b#l�xN~uR� P�8��smB6Zo*n"���I�|	l�l%!m�|65�@��_f��e*��@��`1�7�:89 .{evfdk&i,�@���& �8�I&b4u�tdcjzM�g3�c
l�Viic�e/g�a�G8�Uĭ)� HnphKEq���dbk�
�bp&�$/�zuȠgAwc6w����h�v��G!Ie|��O'ld�l��4y��D���a7!duln�d��p�)"Cu9o}Y�s�`Ng\���]�v�?a&�]{7]I<f�&�Ѧ2$�l�$*�t�i+��T�m�u�x�&��q-*�� �4bq4"*�*�%`ls�K�
&� c>@ ��z!*m�p�1�a�0�1`
�!C�x�E,&�hm��iI(shuf+�ERsqph&����/�  f��A��$&��rT��2 hhűv��T��Oy�j�4YY��P�ae!td5��%2}w�	���T o�*+��~u$gf�j~"�Dh����J` ` `� �0!��NnocE/t%�mZ q m2i�;�(	J0�$��%� "��a��vO�N-uL�u
�aP�p�6'82�` 1�<),�{�ya�� �$��b�g�M�|U7^~�wok$Z����d!)3`2"�,<�W6(����.k�>%�(�8!���n<+4 c|@QtK�%E��?�.) �0,h0A)�L|�L;$v}�IqP{-�$�:)=�}PRt�t�F{���B(��04?+�^Y(��[�gfu��M�%W�i"��`Z.58I� � l�d�Q�T2�sxDp^g�a8�%�Qi;`шz��c%{ei�*H�"��'#�7 rWw-�c2��fHII �PJ(j�`�lq�6(:(��LFtnco�F]
�(
@MI�<a��m%�% !)	d�F=~7�Mw1u^�%0�K24$��h(pu+c�U�)7�Bfagq��n)�8���"(L�oV ��Dn���(�jf�M�J;2�璢{!boj^th�?�c�DM�l!n��a_+X�ff�<a�5�?�xkBv&h0���_:0"F����je�dI)j� �y�!(��0(�pyz/3W�jR�ѨP�LB,�`,c��5�`�7q�VL��e���q�gj<��97G`<!-Vf@�d$R�t!A#�B���51v-�`NFPjg�!p�{DH`�;=8Hs�(6u�sC=z��E�9i.L"|P]]���8I��$�LAw~�f&�Ofx���h�v3f�]�܂:�MSa6�9(=��2��UX��5e��a��Ngmp.rl1�<�Mz�o	�)
`wI]�vo$R$}�D��+`t�hj$��}1��iI�i�jl���c��g�!�o�K�vynr/�c! t*�L�*b�f� #I:x%c��t��}=3h٩�!�I�)�s`�<o�@�L�c#po��r}*0}}o�Yo�n�&8wd`���f� eD��q�M�n`ˀ�,����b!63E�d��L�aJ���IO�--3t/|Ġ�MY0gW�T��u4�|�M�mcy lr�y$wb�qd��$�vA6*k��-�je���MQPV�M�dE4���(f)=�y�1PGzi�D5āo�-<!�+��g}"G��`
& �6L+x�q$yV�Wz�8q�.)�N�$\��ra� ���4�)1� �|!Ox�|�EEW�Mxh�rF;danFdd,�>5%:I���k`}Pwz%jml{by��>6(7"BD dX2 =p�e�(58Fmj|��E�t}�Dr<v�mn_p5��t2c7%<X@4� �&&2੦b �rec��Xi�m���mRt��U�A�x�"��r>+#2%1�:�b(d, b�!)hH3!�q*c	�$�0&$�� ��(<n�<d�i�i��#I��0(c�`(/6�5h��u>=m]rh�B�qI�beh3�l�� Mu0�,0�a_�?5l�b�=d	�e�cGg��zt%��{1`>�#�i772"(+��'bt[0dʑ]g;�B)@�H1N�u���ELI��*��T=��Da�6~�d�a" �c*�4*lpbg.Te~�len�zu�wm'��m�P�wgaE5*I4��j5�H_b6Zg*) %E�Ev|7dFĩ��<W��:-5"�`�"{�g*ɰ4�mqps1l'T�D��ڡ`&UH(-�d!�a�E�!��EE�`Bj���c:f�a�Kk|dO.|a,@exS}�T���@�$��*ov �lE@h *W�q�v�t}ev1Y�E3e�w�v��m��a�oT  yp���`7K�ap�Del|�Bg�ll*��}�gMuǴM���d��UU�'L(�h+OhxLh��oʵ[���1frf-.)�E�he(j+,	m|K/ �2�!O�Rn��A���m|$�ao{3Y)4�n�o�05ڧ�,x�x�mf��X�G��E���mS��?tb.��*���b7l1j���:g&v�Cx	q�'h�cd��oM58�M�(i�E�(�gh�W+�}�\�/Nh~��" (�.tas�gU�ve$7nh.��d�(�&�i@���t$��2~��6�z2uv��$��D8b�8�0�%��)�vm9F�6�-co`<m� j�a2  cl��d(kc)�uj>�g�Qd�| �`'�d�2�i0��2,O��  4"�%��"$>0�=�!�$ &j�I( �a�!~G�!Ơ%J �0 "bh�6P� �+A4q�&6ap��((pi�4;,Ѱ2$�G��,�7�%�do,(j�u�R!M����e3�;��ep�t?`/����qtqlsx�ju$2t{�lR.$�gQZL:q(}1�j�%%kWD^	^�D�g�*5,�p\ygW��o6-sEnnUZ$� ���$Bu�#�`0j��Hb�g��1'䀢�a*�`4��*�J��p~k2d0�V��d�E�fh�%+yCC �uf5G"�5�c}�$Br�+�mU<�GEA5$h�"z�Sg��Rp'4u�o�P:ı�("bp%�:�w��d.d�&귇(t,�s`j�yGYK�8E�}�^*4�e�"L��*<�R,ybG��" .04~ 3�:(:C'*���!?�I�:l�f�(�؃-:Ic�P&̱ge��Wb�u~�Ր:1H0n{�aml.%3
t�B�G�tu7!j��t�l<�E#g�.gn��QnpPi[ZM6�8d�C��:~$B���*p�ecfb�y_4iw�;X�~A� p`q5Y�@5�����|E)c=�-s!W�WC� (1�DPńu/k�$��a1�f�JD�c4^`I"#( '�(�T1!�$G�vf�bd2l�fm@i+L�+1��Ct�$';@.�yx�=�M'�cϮ, eM
d9x Mȃ�B8D����@gtw�pA�oEB̵ee�m&s���6�f��T�0Mg{�B>$�BT0��5z��'���und&$g�S�	<�kE��`(Y`eASO�q�bC|(l��O���ath9�)n_rLh`d�p��.e0��Xx�$�u&�� �b��c�3�\h��eu~$ͭfl�*%*$k��{�6�#mI��/FauQ)��mA5`�s�\H�q�0�1cK�!g�e�%#wx�z 9H)~qm�a1�$d)Ā���(I4(gG�c���s"��+%��q�""�l�%����OZ8��L��0;fg4nu#^D��5e}dz���4t'gx��>"Xi<z� id`Sn�y(��ȾS
1�Yl�?�w9௛RvFD�e`12�@��"�>7~�:�-0wi�Nnt�k�8z�+��%QCc�+gh!�@�-�0r)6�G;i=�.)o�z�
��	@�L���"y��(�s}}-l���`u�W1W2�>/$!�n� J�2.j���ĉ	Y�}�3=nei>(c���lW..�fy�!	89={1�`�,g,�Ok}u,Y�ctyZ+p�r
}(���8)n?r8p$�&�Wvk��Ng�f�0#/L�(L(�j��6MJu߿Q�e�bc��c�e��f5|Db|�o��HKTp ��5x)P1El�}hkR{�b�Tc��$��b��y$0�lxL."���=!��'(C�Lv<�x�	�Ba(s:`�l�E(�#!l�N��e)@U(�@VLc-.nbMvpMoA�hEzl_�aFunA��T~�0%0jU�l�i~��~v(S�CrhSqN`"�i�(:�BQ�).4U���~(h�u*�ol-�Ͳs
 �,%!�"��m-4@-r�lS�m^=c�sr	obb�a�$�SB@�v���&pVOnv$~i!f�]�>f.�b(»dt��fm�n�dPh�~WY�qNMD2a��f0(a�Wr�*�/Z�8#}�}/tc3F��oE�W2�Fd���(9J v�(�`��n4 'u�.ro��aL�j`%�Q��t04n�7f�+�!3�a<|@�fsST$�(u1
8�x �D��kU.gm/�xERƽe�jM��bc���}+50��}c�*H�f�A�h�MBBqH]y0^OhJ
^{:`����9��nv'�o�i�l�kg��(�+bh1
yD�(�t��q���sfu'2�I4<y�h9tc
�t{��$��!
*8�n<�<��!(1c�l�@,
`�"��š1di��#+`j�2����A)��M���u1 �t�D!�o`
�� �8�YJ `)d�55-Kbly{hO�
�"�!ѥ��"���V@,y�f-�p�S��Ng~��pYaj�/4��5bl�a�ct�v%@&J ,b�1+!��yf'd�y�L��xP �KO��pwPWioCmn%M7��&����8f�0�$t.s��Q
^'�nT!&U/�4i�bb�%x�c}p9�)��)<�
]0 ��2nٿ�kuiDp?�8%�$>�we5J8,A^rhAZD��\PF���4�*�� �p	`�)���L�!Gh��0Ua;�w�$5�LqlŶ";(��X�|udU*8C�"0 ��0���b�0]i�,�e3v�J�w��~-&x	�ip|�f`=�rH��8�Lb(�Ltm^�L�\l�C'�ok	�s{/��lF�
�7�t#�J�Y�kGl0y���(��Msfw?Tmۃ"T,^��hKF<Bf�dVo)e�6�c�.9��C��S�a�}a�}+�Ikqyg� xp&�*�8�)# )�A2ma�!u}Mp�g:�n��d/�:sgIu�%D�wF=)㸖'>����bEG�0%M?J���b}}>C/7��aepE:|E�cdx�b
�B�.���Kz [�h�'iC)��$��E����@4�
�(f,bf� .�Gi�A�#\)���e�4p�Dra���` �A$$�(f!
s<@b�`Io`�o��e��|1�z�<gtu�4[`� S}in��Z!'g+`�ʧ �k~Q�����Bb�1m�q����K�z|�t1a_2c\ru,�x �,i�$AUA�+�6(�= 6e8E3�g�k#pJ�ssV0D_j�4�l'�*�`�U�Ak!�\QAJ�'O&I� �|�"R���qh�kMij'���A�k�C@C5�iKIw �*GLO�+ �D��c���xE�a�Q�A�jj�i#��oHbON3�h�!f��s�	��9;T'�c5;�C+���}�-�/9��$t��@5a)�ZGc�|n�=R�b�Ei;md��!��)`(��kv�a��mw��A���d��z�e`��p� A)�y;j��q�]Rab}m�%27vv}w��sf�y�-�d�t�a\��Rgt��|�	h"��� 2g�Elz�3�����d�C]w�z-M�Qx-Ua$ ")Mu�miPm�e���! 4�*%��);Rhf��mm$MrϐG���&]~C�u�~d%Xr>� Ire��IES���i(v�l(�h-n (Z.�a7a/Mb!��lg��0kgi3��N�=)z`�Ыu>/Ye�ok	YK���CF4���`�$��Q��8u�*�nhS3_�Yi)p6Jy!/��w�c1an�=Q?�4g}6�jey@ry�p)�*d�R"?|n�ptr�h�+�	�O���"`	8l�l>�*<��2�Sua-�`sP&~�PKb�S/[~@��GQ7�Ef�mÎ�[2�h�y�v�a >��0X��(hd�z!�d��6i$4pN�pSxTd>`G+"b�B8Y`"+8��&��Ux�/�)c�`*�nq�?ɞ8s kcy8"%��&e!vb1a�Eaj�C,�`c�-,+B]s�p�i%�kjD/Eo#��6�mD��I	���2P�-SsL���mm5Qw/:#��#8w,/'�Rv�2ma�>����)9s<aAOK@`�E.��c�|�~(R4�`��,a�98i�Eg�c� |w=1j��t�%u�S2b�uw�����-�F#O')%8B!I�*i��h�c��lxk�k�Fuv%�@p>�10�,<p�� 2p'k���cY\K~%�`cU7�C�p�*�`�z��k���/�l,�@$M�lq~'t�VEx6�V�",Dt� ��&=T'�bua�l�`A�qPp�Ti/+Xp`0'�`�ag�c��b݃$Qoj�-AB��dE1S�%@�`e#3��i%/$�i&gB2/=���TAs�.[p�)xaD�)d�`��<d��s��j%v�n�t�.�ge�u!�l(ocR�x�dg�D�u���c3C/,�!+` �e�q��!#��1Q�Ep�,j �b�y�x!$mg��&i$p`���hзdmRr��qf�	�0{��2]���%��`�~
�x<�Cs�<fH���8��Sjv>�#"c)'bT&byl�(�6p(��ѣp̏N7!J@-���N�њ *���Gi|�t���>obL�|-�g�G�s>P$g+E9��� #l��X��t�E�0k�plE +�/ozuN*��d�!3�rM���>fL"4� Yv0�2z&6��7d =r�t!�gtQ1b'��Mi�ha�� JCm$-&ev/tK�x�8=#^�ݴ�u!(gOmZz���aB\���%�a�!��	5�k�g�"F�;C`!2$j# ���cA)2'`�9]�<6�H1o!ncaTC��tz1��3��i;9>�8Nyf�(K5�]�UcUQ�7y']=	�}~�,gݐ�`x8t$ep�.�c$�Ce��Lq�S+
��(O3 ��U$�c�m-c��u(�d|D�� p@gx;�pk�3�8gu�< B!yU hak&k�e�}"&ktA��סUp�i�Xa��$�ly�T$�& &0�i?A	�icZ!a�%1pj�`s��e�%�i"��Z/8��]!�)��N5U� E3�� w6$^�8N���slW�x~"�G�huI-t]n��pl{x|*A�:�N�in��IkZ�8�`�!YX��eU�M��(��u�t�e a5�E�\g�l-�	�1b�/Gc�|�Spk��r�d��_qa�/����,�/�RC<"!-m/&(@ <jj��e��{d�8s1�f�dB|���%��=S,y3��yVgm?t��	x#(�I3%��g�m)-Q�?�)�h墚 �v	�iL�@#t.L��n5�7$zF%�n�#B�
p�Q 8t&�" >$p�Hp10�%w0�pvWjD/UdsU0�c.�(�&�� 	  b	���G(G�T'�Nnazc��Ouz��|�& E�"�A�k�-�p! )�3 %fD;����e�/���sLa-9C2�G�oM� �,10 3}�|�f`�nE~���P)b~� s�'���2�&�:{���y��loxp�:�n�<o��fm�}�att'�*���s!a0!���q�<q�Ha��8�K䩸 ��c�9se֘z>�aupyoi;�i�k�>)�dw�hGUUj-
)&�p�gt����6 ��d	mNim���a��nf/�DGo�.���3&N�;�~�}�h6.pEgrw-I_��dcm�F�K��� e�C��If0<xodxG*��f�B�px� �.!ys|�EQ<Ae�=u.R�/��b$
!�T,d�1p(�
d��iYm[E<3��edN��qcd+l%P�toq$M_~�: E j�BSM���x��! � ��+�Y}�F�v	pM�mSd+�0=ib&���ihs4U#@�8ao�y�Y>lU�xL�1��=z:4�"`� 0t3�0| �H�,H�v}�t�V�f%.)�,4Y`nt]�7x��s�zt[ &m� �4"J�B#�$0�A:c�� � ���r6�i�0�!�   ��z��J
)�(��:�dqe	 �R)-ZB�N Nl�&5uO.j}c��E�uX�9Ԩm�D&�i>�� w�\e�qMi qs�7!�AbG�me�eg�M臡zE�9��AH�
xdyW�L%C�0�>q^�w��o@���]q�0-
m��L�"m�u4~Io��qh7"�d3zoܡeAgԽ!Z*�E���q|hn���lep�(���D�$�i,�A�]ldBt�{�4U�EO�c�  (define-key cua--region-keymap    cua-rectangle-mark-key 'cua-toggle-rectangle-mark)
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
