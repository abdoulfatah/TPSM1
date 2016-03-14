;;; pcvs.el --- a front-end to CVS  -*- lexical-binding:t -*-

;; Copyright (C) 1991-2015 Free Software Foundation, Inc.

;; Author: (The PCL-CVS Trust) pcl-cvs@cyclic.com
;;	(Per Cederqvist) ceder@lysator.liu.se
;;	(Greg A. Woods) woods@weird.com
;;	(Jim Blandy) jimb@cyclic.com
;;	(Karl Fogel) kfogel@floss.red-bean.com
;;	(Jim Kingdon) kingdon@cyclic.com
;;	(Stefan Monnier) monnier@cs.yale.edu
;;	(Greg Klanderman) greg@alphatech.com
;;	(Jari Aalto+mail.emacs) jari.aalto@poboxes.com
;; Maintainer: (Stefan Monnier) monnier@gnu.org
;; Keywords: CVS, vc, release management

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

;;; Commentary:

;; PCL-CVS is a front-end to the CVS version control system.
;; It presents the status of all the files in your working area and
;; allows you to commit/update several of them at a time.
;; Compare with the general Emacs utility vc-dir, which tries
;; to be VCS-agnostic.  You may find PCL-CVS better/faster for CVS.

;; PCL-CVS was originally written by Per Cederqvist many years ago.  This
;; version derives from the XEmacs-21 version, itself based on the 2.0b2
;; version (last release from Per).  It is a thorough rework.

;; PCL-CVS is not a replacement for VC, but adds extra functionality.
;; As such, I've tried to make PCL-CVS and VC interoperate seamlessly
;; (I also use VC).

;; To use PCL-CVS just use `M-x cvs-examine RET <dir> RET'.
;; There is a TeXinfo manual, which can be helpful to get started.

;;; Bugs:

;; - Extracting an old version seems not to recognize encoding correctly.
;;   That's probably because it's done via a process rather than a file.

;;; Todo:

;; ******** FIX THE DOCUMENTATION *********
;;
;; - rework the displaying of error messages.
;; - allow to flush messages only
;; - allow to protect files like ChangeLog from flushing
;; - query the user for cvs-get-marked (for some cmds or if nothing's selected)
;; - don't return the first (resp last) FI if the cursor is before
;;   (resp after) it.
;; - allow cvs-confirm-removals to force always confirmation.
;; - cvs-checkout should ask for a revision (with completion).
;; - removal confirmation should allow specifying another file name.
;;
;; - hide fileinfos without getting rid of them (will require ewok work).
;; - add toolbar entries
;; - marking
;;    marking directories should jump to just after the dir.
;;    allow (un)marking directories at a time with the mouse.
;;    allow cvs-cmd-do to either clear the marks or not.
;;    add a "marks active" notion, like transient-mark-mode does.
;; - liveness indicator
;; - indicate in docstring if the cmd understands the `b' prefix(es).
;; - call smerge-mode when opening CONFLICT files.
;; - have vc-checkin delegate to cvs-mode-commit when applicable
;; - higher-level CVS operations
;;    cvs-mode-rename
;;    cvs-mode-branch
;; - module-level commands
;;    add support for parsing 'modules' file ("cvs co -c")
;;    cvs-mode-rcs2log
;;    cvs-rdiff
;;    cvs-release
;;    cvs-import
;;    C-u M-x cvs-checkout should ask for a cvsroot
;;    cvs-mode-handle-new-vendor-version
;; 	- checks out module, or alternately does update join
;; 	- does "cvs -n tag LAST_VENDOR" to find old files into *cvs*
;;    cvs-export
;; 	(with completion on tag names and hooks to help generate full releases)
;; - display stickiness information.  And current CVS/Tag as well.
;; - write 'cvs-mode-admin' to do arbitrary 'cvs admin' commands
;;   Most interesting would be version removal and log message replacement.
;;   The last one would be neat when called from log-view-mode.
;; - cvs-mode-incorporate
;; 	It would merge in the status from one *cvs* buffer into another.
;; 	This would be used to populate such a buffer that had been created with
;; 	a `cvs {update,status,checkout} -l'.
;; - cvs-mode-(i)diff-other-{file,buffer,cvs-buffer}
;; - offer the choice to kill the process when the user kills the cvs buffer.
;; 	right now, it's killed without further ado.
;; - make `cvs-mode-ignore' allow manually entering a pattern.
;; 	to which dir should it apply ?
;; - cvs-mode-ignore should try to remove duplicate entries.
;; - maybe poll/check CVS/Entries files to react to external `cvs' commands ?
;; - some kind of `cvs annotate' support ?
;; 	but vc-annotate can be used instead.
;; - proper `g' that passes safe args and uses either cvs-status or cvs-examine
;;   maybe also use cvs-update depending on I-don't-know-what.
;; - add message-levels so that we can hide some levels of messages

;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'ewoc)				;Ewoc was once cookie
(require 'pcvs-defs)
(require 'pcvs-util)
(require 'pcvs-parse)
(require 'pcvs-info)
(require 'vc-cvs)


;;;;
;;;; global vars
;;;;

(defvar cvs-cookies) ;;nil
  ;;"Handle for the cookie structure that is displayed in the *cvs* buffer.")
;;(make-variable-buffer-local 'cvs-cookies)

;;;;
;;;; Dynamically scoped variables
;;;;

(defvar cvs-from-vc nil "Bound to t inside VC advice.")

;;;;
;;;; flags variables
;;;;

(defun cvs-defaults (&rest defs)
  (let ((defs (cvs-first defs cvs-shared-start)))
    (append defs
	    (make-list (- cvs-shared-start (length defs)) (car defs))
	    cvs-shared-flags)))

;; For cvs flags, we need to add "-f" to override the cvsrc settings
;; we also want to evict the annoying -q and -Q options that hide useful
;; information from pcl-cvs.
(cvs-flags-define cvs-cvs-flags '(("-f")))

(cvs-flags-define cvs-checkout-flags (cvs-defaults '("-P")))
(cvs-flags-define cvs-status-flags (cvs-defaults '("-v") nil))
(cvs-flags-define cvs-log-flags (cvs-defaults nil))
(cvs-flags-define cvs-diff-flags (cvs-defaults '("-u" "-N") '("-c" "-N") '("-u" "-b")))
(cvs-flags-define cvs-tag-flags (cvs-defaults nil))
(cvs-flags-define cvs-add-flags (cvs-defaults nil))
(cvs-flags-define cvs-commit-flags (cvs-defaults nil))
(cvs-flags-define cvs-remove-flags (cvs-defaults nil))
;;(cvs-flags-define cvs-undo-flags (cvs-defaults nil))
(cvs-flags-define cvs-update-flags (cvs-defaults '("-d" "-P")))

(defun cvs-reread-cvsrc ()
  "Reset the default arguments to those in the `cvs-cvsrc-file'."
  (interactive)
  (condition-case nil
      (with-temp-buffer
	(insert-file-contents cvs-cvsrc-file)
	;; fetch the values
	(dolist (cmd '("cvs" "checkout" "status" "log" "diff" "tag"
		       "add" "commit" "remove" "update"))
	  (goto-char (point-min))
	  (when (re-search-forward
		 (concat "^" cmd "\\(\\s-+\\(.*\\)\\)?$") nil t)
	    (let* ((sym (intern (concat "cvs-" cmd "-flags")))
		   (val (split-string-and-unquote (or (match-string 2) ""))))
	      (cvs-flags-set sym 0 val))))
	;; ensure that cvs doesn't have -q or -Q
	(cvs-flags-set 'cvs-cvs-flags 0
		       (cons "-f"
			     (cdr (cvs-partition
				   (lambda (x) (member x '("-q" "-Q" "-f")))
				   (cvs-flags-query 'cvs-cvs-flags
						    nil 'noquery))))))
      (file-error nil)))

;; initialize to cvsrc's default values
(cvs-reread-cvsrc)


;;;;
;;;; Mouse bindings and mode motion
;;;;

(defvar cvs-minor-current-files)

(defun cvs-menu (e)
  "Popup the CVS menu."
  (interactive "e")
  (let ((cvs-minor-current-files
	 (list (ewoc-data (ewoc-locate
			   cvs-cookies (posn-point (event-end e)))))))
    (popup-menu cvs-menu e)))

(defvar cvs-mode-line-process nil
  "Mode-line control for displaying info on cvs process status.")


;;;;
;;;; Query-Type-Descriptor for Tags
;;;;

(autoload 'cvs-status-get-tags "cvs-status")
(defun cvs-tags-list ()
  "Return a list of acceptable tags, ready for completions."
  (cl-assert (cvs-buffer-p))
  (let ((marked (cvs-get-marked)))
    `(("BASE") ("HEAD")
      ,@(when marked
          (with-temp-buffer
            (process-file cvs-program
                          nil           ;no input
                          t		;output to current-buffer
                          nil           ;don't update display while running
                          "status"
                          "-v"
                          (cvs-fileinfo->full-name (car marked)))
            (goto-char (point-min))
            (let ((tags (cvs-status-get-tags)))
              (when (listp tags) tags)))))))

(defvar cvs-tag-history nil)
(defconst cvs-qtypedesc-tag
  (cvs-qtypedesc-create 'identity 'identity 'cvs-tags-list 'cvs-tag-history))

;;;;

(defun cvs-mode! (&optional -cvs-mode!-fun)
  "Switch to the *cvs* buffer.
If -CVS-MODE!-FUN is provided, it is executed *cvs* being the current buffer
  and with its window selected.  Else, the *cvs* buffer is simply selected.
-CVS-MODE!-FUN is called interactively if applicable and else with no argument."
  (let* ((-cvs-mode!-buf (current-buffer))
	 (cvsbuf (cond ((cvs-buffer-p) (current-buffer))
		       ((and cvs-buffer (cvs-buffer-p cvs-buffer)) cvs-buffer)
		       (t (error "can't find the *cvs* buffer"))))
	 (-cvs-mode!-wrapper cvs-minor-wrap-function)
	 (-cvs-mode!-cont (lambda ()
			    (save-current-buffer
			      (if (commandp -cvs-mode!-fun)
				  (call-interactively -cvs-mode!-fun)
				(funcall -cvs-mode!-fun))))))
    (if (not -cvs-mode!-fun) (set-buffer cvsbuf)
      (let ((cvs-mode!-buf (current-buffer))
	    (cvs-mode!-owin (selected-window))
	    (cvs-mode!-nwin (get-buffer-window cvsbuf 'visible)))
	(unwind-protect
	    (progn
	      (set-buffer cvsbuf)
	      (when cvs-mode!-nwin (select-window cvs-mode!-nwin))
	      (if -cvs-mode!-wrapper
		  (funcall -cvs-mode!-wrapper -cvs-mode!-buf -cvs-mode!-cont)
		(funcall -cvs-mode!-cont)))
	  (set-buffer cvs-mode!-buf)
	  (when (and cvs-mode!-nwin (eq cvs-mode!-nwin (selected-window)))
	    ;; the selected window has not been changed by FUN
	    (select-window cvs-mode!-owin)))))))

;;;;
;;;; Prefixes
;;;;

(defvar cvs-branches (list cvs-vendor-branch "HEAD" "HEAD"))
(cvs-prefix-define cvs-branch-prefix
  "Current selected branch."
  "version"
  (cons cvs-vendor-branch cvs-branches)
  cvs-qtypedesc-tag)

(defun cvs-set-branch-prefix (arg)
  "Set the branch prefix to take action at the next command.
See `cvs-prefix-set' for a further the description of the behavior.
\\[universal-argument] 1 selects the vendor branch
and \\[universal-argument] 2 selects the HEAD."
  (interactive "P")
  (cvs-mode!)
  (cvs-prefix-set 'cvs-branch-prefix arg))

(defun cvs-add-branch-prefix (flags &optional arg)
  "Add branch selection argument if the branch prefix was set.
The argument is added (or not) to the list of FLAGS and is constructed
by appending the branch to ARG which defaults to \"-r\"."
  (let ((branch (cvs-prefix-get 'cvs-branch-prefix)))
    ;; deactivate the secondary prefix, even if not used.
    (cvs-prefix-get 'cvs-secondary-branch-prefix)
    (if branch (cons (concat (or arg "-r") branch) flags) flags)))

(cvs-prefix-define cvs-secondary-branch-prefix
  "Current secondary selected branch."
  "version"
  (cons cvs-vendor-branch cvs-branches)
  cvs-qtypedesc-tag)

(defun cvs-set-secondary-branch-prefix (arg)
  "Set the branch prefix to take action at the next command.
See `cvs-prefix-set' for a further the description of the behavior.
\\[universal-argument] 1 selects the vendor branch
and \\[universal-argument] 2 selects the HEAD."
  (interactive "P")
  (cvs-mode!)
  (cvs-prefix-set 'cvs-secondary-branch-prefix arg))

(defun cvs-add-secondary-branch-prefix (flags &optional arg)
  "Add branch selection argument if the secondary branch prefix was set.
The argument is added (or not) to the list of FLAGS and is constructed
by appending the branch to ARG which defaults to \"-r\".
Since the `cvs-secondary-branch-prefix' is only active if the primary
prefix is active, it is important to read the secondary prefix before
the primary since reading the primary can deactivate it."
  (let ((branch (and (cvs-prefix-get 'cvs-branch-prefix 'read-only)
		     (cvs-prefix-get 'cvs-secondary-branch-prefix))))
    (if branch (cons (concat (or arg "-r") branch) flags) flags)))

;;;;

(define-minor-mode cvs-minor-mode
  "This mode is used for buffers related to a main *cvs* buffer.
All the `cvs-mode' buffer operations are simply rebound under
the \\[cvs-mode-map] prefix."
  nil " CVS"
  :group 'pcl-cvs)
(put 'cvs-minor-mode 'permanent-local t)


(defvar cvs-temp-buffers nil)
(defun cvs-temp-buffer (&optional cmd normal nosetup)
  "Create a temporary buffer to run CMD in.
If CMD is a string, use it to lookup `cvs-buffer-name-alist' to find
the buffer name to be used and its major mode.

The selected window will not be changed.  The new buffer will not maintain undo
information and will be read-only unless NORMAL is non-nil.  It will be emptied
\(unless NOSETUP is non-nil) and its `default-directory' will be inherited
from the current buffer."
  (let* ((cvs-buf (current-buffer))
	 (info (cdr (assoc cmd cvs-buffer-name-alist)))
	 (name (eval (nth 0 info) `((cmd . ,cmd))))
	 (mode (nth 1 info))
	 (dir default-directory)
	 (buf (cond
	       (name (cvs-get-buffer-create name))
	       ((and (bufferp cvs-temp-buffer) (buffer-live-p cvs-temp-buffer))
		cvs-temp-buffer)
	       (t
		(set (make-local-variable 'cvs-temp-buffer)
		     (cvs-get-buffer-create
		      (eval cvs-temp-buffer-name `((dir . ,dir)))
                      'noreuse))))))

    ;; Handle the potential pre-existing process.
    (let ((proc (get-buffer-process buf)))
      (when (and (not normal) (processp proc)
		 (memq (process-status proc) '(run stop)))
	(if cmd
	    ;; When CMD is specified, the buffer is normally shown to the
	    ;; user, so interrupting the process is not harmful.
	    ;; Use `delete-process' rather than `kill-process' otherwise
	    ;; the pending output of the process will still get inserted
	    ;; after we erase the buffer.
	    (delete-process proc)
	  (error "Can not run two cvs processes simultaneously"))))

    (if (not name) (kill-local-variable 'other-window-scroll-buffer)
      ;; Strangely, if no window is created, `display-buffer' ends up
      ;; doing a `switch-to-buffer' which does a `set-buffer', hence
      ;; the need for `save-excursion'.
      (unless nosetup (save-excursion (display-buffer buf)))
      ;; FIXME: this doesn't do the right thing if the user later on
      ;; does a `find-file-other-window' and `scroll-other-window'
      (set (make-local-variable 'other-window-scroll-buffer) buf))

    (add-to-list 'cvs-temp-buffers buf)

    (with-current-buffer buf
      (setq buffer-read-only nil)
      (setq default-directory dir)
      (unless nosetup
        ;; Disable undo before calling erase-buffer since it may generate
        ;; a very large and unwanted undo record.
        (buffer-disable-undo)
        (erase-buffer))
      (set (make-local-variable 'cvs-buffer) cvs-buf)
      ;;(cvs-minor-mode 1)
      (let ((lbd list-buffers-directory))
	(if (fboundp mode) (funcall mode) (fundamental-mode))
	(when lbd (setq list-buffers-directory lbd)))
      (cvs-minor-mode 1)
      ;;(set (make-local-variable 'cvs-buffer) cvs-buf)
      (if normal
          (buffer-enable-undo)
	(setq buffer-read-only t)
	(buffer-disable-undo))
      buf)))

(defun cvs-mode-kill-buffers ()
  "Kill all the \"temporary\" buffers created by the *cvs* buffer."
  (interactive)
  (dolist (buf cvs-temp-buffers) (ignore-errors (kill-buffer buf))))

(defun cvs-make-cvs-buffer (dir &optional new)
  "Create the *cvs* buffer for directory DIR.
If non-nil, NEW means to create a new buffer no matter what."
  ;; the real cvs-buffer creation
  (setq dir (cvs-expand-dir-name dir))
  (let* ((buffer-name (eval cvs-buffer-name `((dir . ,dir))))
	 (buffer
	  (or (and (not new)
		   (eq cvs-reuse-cvs-buffer 'current)
		   (cvs-buffer-p)	;reuse the current buffer if possible
		   (current-buffer))
	      ;; look for another cvs buffer visiting the same directory
	      (save-excursion
		(unless new
		  (cl-dolist (buffer (cons (current-buffer) (buffer-list)))
		    (set-buffer buffer)
		    (and (cvs-buffer-p)
			 (pcase cvs-reuse-cvs-buffer
			   (`always t)
			   (`subdir
			    (or (string-prefix-p default-directory dir)
				(string-prefix-p dir default-directory)))
			   (`samedir (string= default-directory dir)))
			 (cl-return buffer)))))
	      ;; we really have to create a new buffer:
	      ;; we temporarily bind cwd to "" to prevent
	      ;; create-file-buffer from using directory info
	      ;; unless it is explicitly in the cvs-buffer-name.
	      (cvs-get-buffer-create buffer-name new))))
    (with-current-buffer buffer
      (or
       (and (string= dir default-directory) (cvs-buffer-p)
	    ;; just a refresh
	    (ignore-errors
	      (cvs-cleanup-collection cvs-cookies nil nil t)
	      (current-buffer)))
       ;; setup from scratch
       (progn
	 (setq default-directory dir)
	 (setq buffer-read-only nil)
	 (erase-buffer)
	 (insert "Repository : " (directory-file-name (cvs-get-cvsroot))
		 "\nModule     : " (cvs-get-module)
		 "\nWorking dir: " (abbreviate-file-name dir)
		 (if (not (file-readable-p "CVS/Tag")) "\n"
		   (let ((tag (cvs-file-to-string "CVS/Tag")))
		     (cond
		      ((string-match "\\`T" tag)
		       (concat "\nTag        : " (substring tag 1)))
		      ((string-match "\\`D" tag)
		       (concat "\nDate       : " (substring tag 1)))
		      ("\n"))))
		 "\n")
	 (setq buffer-read-only t)
	 (cvs-mode)
	 (set (make-local-variable 'list-buffers-directory) buffer-name)
	 ;;(set (make-local-variable 'cvs-temp-buffer) (cvs-temp-buffer))
	 (let ((cookies (ewoc-create 'cvs-fileinfo-pp "\n\n" "\n" t)))
	   (set (make-local-variable 'cvs-cookies) cookies)
	   (add-hook 'kill-buffer-hook
		     (lambda ()
		       (ignore-errors (kill-buffer cvs-temp-buffer)))
		     nil t)
	   ;;(set-buffer buf)
	   buffer))))))

(cl-defun cvs-cmd-do (cmd dir flags fis new
			&key cvsargs noexist dont-change-disc noshow)
  (let* ((dir (file-name-as-directory
	       (abbreviate-file-name (expand-file-name dir))))
	 (cvsbuf (cvs-make-cvs-buffer dir new)))
    ;; Check that dir is under CVS control.
    (unless (file-directory-p dir)
      (error "%s is not a directory" dir))
    (unless (or noexist (file-directory-p (expand-file-name "CVS" dir))
		(file-expand-wildcards (expand-file-name "*/CVS" dir)))
      (error "%s does not contain CVS controlled files" dir))

    (set-buffer cvsbuf)
    (cvs-mode-run cmd flags fis
		  :cvsargs cvsargs :dont-change-disc dont-change-disc)

    (if noshow cvsbuf
      (let ((pop-up-windows nil)) (pop-to-buffer cvsbuf)))))
;;      (funcall (if (and (boundp 'pop-up-frames) pop-up-frames)
;;		   'pop-to-buffer 'switch-to-buffer)
;;	       cvsbuf))))

(defun cvs-run-process (args fis postprocess &optional single-dir)
  (cl-assert (cvs-buffer-p cvs-buffer))
  (save-current-buffer
    (let ((procbuf (current-buffer))
	  (cvsbuf cvs-buffer)
	  (single-dir (or single-dir (eq cvs-execute-single-dir t))))

      (set-buffer procbuf)
      (goto-char (point-max))
      (unless (bolp) (let ((inhibit-read-only t)) (insert "\n")))
      ;; find the set of files we'll process in this round
      (let* ((dir+files+rest
	      (if (or (null fis) (not single-dir))
		  ;; not single-dir mode: just process the whole thing
		  (list "" (mapcar 'cvs-fileinfo->full-name fis) nil)
		;; single-dir mode: extract the same-dir-elements
		(let ((dir (cvs-fileinfo->dir (car fis))))
		  ;; output the concerned dir so the parser can translate paths
		  (let ((inhibit-read-only t))
		    (insert "pcl-cvs: descending directory " dir "\n"))
		  ;; loop to find the same-dir-elems
		  (cl-do* ((files () (cons (cvs-fileinfo->file fi) files))
                           (fis fis (cdr fis))
                           (fi (car fis) (car fis)))
		      ((not (and fis (string= dir (cvs-fileinfo->dir fi))))
		       (list dir files fis))))))
	     (dir (nth 0 dir+files+rest))
	     (files (nth 1 dir+files+rest))
	     (rest (nth 2 dir+files+rest)))

	(add-hook 'kill-buffer-hook
		  (lambda ()
		    (let ((proc (get-buffer-process (current-buffer))))
		      (when (processp proc)
			(set-process-filter proc nil)
			;; Abort postprocessing but leave the sentinel so it
			;; will update the list of running procs.
			(process-put proc 'cvs-postprocess nil)
			(interrupt-process proc))))
		  nil t)

	;; create the new process and setup the procbuffer correspondingly
	(let* ((msg (cvs-header-msg args fis))
	       (args (append (cvs-flags-query 'cvs-cvs-flags nil 'noquery)
			     (if cvs-cvsroot (list "-d" cvs-cvsroot))
			     args
			     files))
	       ;; If process-connection-type is nil and the repository
	       ;; is accessed via SSH, a bad interaction between libc,
	       ;; CVS and SSH can lead to garbled output.
	       ;; It might be a glibc-specific problem (but it can also happens
	       ;; under Mac OS X, it seems).
	       ;; It seems that using a pty can help circumvent the problem,
	       ;; but at the cost of screwing up when the process thinks it
	       ;; can ask for user input (such as password or host-key
	       ;; confirmation).  A better workaround is to set CVS_RSH to
	       ;; an appropriate script, or to use a later version of CVS.
	       (process-connection-type nil) ; Use a pipe, not a pty.
	       (process
		;; the process will be run in the selected dir
		(let ((default-directory (cvs-expand-dir-name dir)))
		  (apply 'start-file-process "cvs" procbuf cvs-program args))))
	  ;; setup the process.
	  (process-put process 'cvs-buffer cvs-buffer)
	  (with-current-buffer cvs-buffer (cvs-update-header msg 'add))
	  (process-put process 'cvs-header msg)
	  (process-put
	   process 'cvs-postprocess
	   (if (null rest)
	       ;; this is the last invocation
               postprocess
	     ;; else, we have to register ourselves to be rerun on the rest
	     (lambda () (cvs-run-process args rest postprocess single-dir))))
	  (set-process-sentinel process 'cvs-sentinel)
	  (set-process-filter process 'cvs-update-filter)
	  (set-marker (process-mark process) (point-max))
	  (ignore-errors (process-send-eof process)) ;close its stdin to avoid hangs

	  ;; now finish setting up the cvs-buffer
	  (set-buffer cvsbuf)
	  (setq cvs-mode-line-process (symbol-name (process-status process)))
	  (force-mode-line-update)))))

  ;; The following line is said to improve display updates on some
  ;; emacsen. It shouldn't be needed, but it does no harm.
  (sit-for 0))

(defun cvs-header-msg (args fis)
  (let* ((lastarg nil)
	 (args (mapcar (lambda (arg)
			 (cond
			  ;; filter out the largish commit message
			  ((and (eq lastarg nil) (string= arg "commit"))
			   (setq lastarg 'commit) arg)
			  ((and (eq lastarg 'commit) (string= arg "-m"))
			   (setq lastarg '-m) arg)
			  ((eq lastarg '-m)
			   (setq lastarg 'done) "<log message>")
			  ;; filter out the largish `admin -mrev:msg' message
			  ((and (eq lastarg nil) (string= arg "admin"))
			   (setq lastarg 'admin) arg)
			  ((and (eq lastarg 'admin)
				(string-match "\\`-m[^:]*:" arg))
			   (setq lastarg 'done)
			   (concat (match-string 0 arg) "<log message>"))
			  ;; Keep the rest as is.
			  (t arg)))
		       args)))
    (concat cvs-program " "
	    (combine-and-quote-strings
	     (append (cvs-flags-query 'cvs-cvs-flags nil 'noquery)
		     (if cvs-cvsroot (list "-d" cvs-cvsroot))
		     args
		     (mapcar 'cvs-fileinfo->full-name fis))))))

(defun cvs-update-header (cmd add)
  (let* ((hf (ewoc-get-hf cvs-cookies))
	 (str (car hf))
	 (done "")
	 (tin (ewoc-nth cvs-cookies 0)))
    ;; look for the first *real* fileinfo (to determine emptiness)
    (while
	(and tin
	     (memq (cvs-fileinfo->type (ewoc-data tin))
		   '(MESSAGE DIRCHANGE)))
      (setq tin (ewoc-next cvs-cookies tin)))
    (if add
        (progn
          ;; Remove the default empty line, if applicable.
          (if (not (string-match "." str)) (setq str "\n"))
          (setq str (concat "-- Running " cmd " ...\n" str)))
      (if (not (string-match
                ;; FIXME:  If `cmd' is large, this will bump into the
                ;; compiled-regexp size limit.  We could drop the "^" anchor
                ;; and use search-forward to circumvent the problem.
		(concat "^-- Running " (regexp-quote cmd) " \\.\\.\\.\n") str))
	  (error "Internal PCL-CVS error while removing message")
	(setq str (replace-match "" t t str))
        ;; Re-add the default empty line, if applicable.
        (if (not (string-match "." str)) (setq str "\n\n"))
	(setq done (concat "-- last cmd: " cmd " --\n"))))
    ;; set the new header and footer
    (ewoc-set-hf cvs-cookies
		 str (concat "\n--------------------- "
			     (if tin "End" "Empty")
			     " ---------------------\n"
			     done))))


(defun cvs-sentinel (proc _msg)
  "Sentinel for the cvs update process.
This is responsible for parsing the output from the cvs update when
it is finished."
  (when (memq (process-status proc) '(signal exit))
    (let ((cvs-postproc (process-get proc 'cvs-postprocess))
	  (cvs-buf (process-get proc 'cvs-buffer))
          (procbuf (process-buffer proc)))
      (unless (buffer-live-p cvs-buf) (setq cvs-buf nil))
      (unless (buffer-live-p procbuf) (setq procbuf nil))
      ;; Since the buffer and mode line will show that the
      ;; process is dead, we can delete it now.  Otherwise it
      ;; will stay around until M-x list-processes.
      (process-put proc 'postprocess nil)
      (delete-process proc)
      ;; Don't do anything if the main buffer doesn't exist any more.
      (when cvs-buf
	(with-current-buffer cvs-buf
	  (cvs-update-header (process-get proc 'cvs-header) nil)
	  (setq cvs-mode-line-process (symbol-name (process-status proc)))
	  (force-mode-line-update)
	  (when cvs-postproc
	    (if (null procbuf)
		;;(set-process-buffer proc nil)
		(error "cvs' process buffer was killed")
	      (with-current-buffer procbuf
		;; Do the postprocessing like parsing and such.
		(save-excursion
                  (funcall cvs-postproc)))))))
      ;; Check whether something is left.
      (when (and procbuf (not (get-buffer-process procbuf)))
        (with-current-buffer procbuf
          ;; IIRC, we enable undo again once the process is finished
          ;; for cases where the output was inserted in *vc-diff* or
          ;; in a file-like buffer.  --Stef
          (buffer-enable-undo)
          (with-current-buffer (or cvs-buf (current-buffer))
            (message "CVS process has completed in %s"
                     (buffer-name))))))))

(defun cvs-parse-process (dcd &optional subdir old-fis)
  "Parse the output of a cvs process.
DCD is the `dont-change-disc' flag to use when parsing that output.
SUBDIR is the subdirectory (if any) where this command was run.
OLD-FIS is the list of fileinfos on which the cvs command was applied and
  which should be considered up-to-date if they are missing from the output."
  (when (eq system-type 'darwin)
    ;; Fixup the ^D^H^H inserted at beginning of buffer sometimes on MacOSX
    ;; because of the call to `process-send-eof'.
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\\^D+" nil t)
	(let ((inhibit-read-only t))
	  (delete-region (match-beginning 0) (match-end 0))))))
  (let* ((fileinfos (cvs-parse-buffer 'cvs-parse-table dcd subdir))
	 last)
    (with-current-buffer cvs-buffer
      ;; Expand OLD-FIS to actual files.
      (let ((fis nil))
	(dolist (fi old-fis)
	  (setq fis (if (eq (cvs-fileinfo->type fi) 'DIRCHANGE)
			(nconc (ewoc-collect cvs-cookies 'cvs-dir-member-p
					     (cvs-fileinfo->dir fi))
			       fis)
		      (cons fi fis))))
	(setq old-fis fis))
      ;; Drop OLD-FIS which were already up-to-date.
      (let ((fis nil))
	(dolist (fi old-fis)
	  (unless (eq (cvs-fileinfo->type fi) 'UP-TO-DATE) (push fi fis)))
	(setq old-fis fis))
      ;; Add the new fileinfos to the ewoc.
      (dolist (fi fileinfos)
	(setq last (cvs-addto-collection cvs-cookies fi last))
	;; This FI was in the output, so remove it from OLD-FIS.
	(setq old-fis (delq (ewoc-data last) old-fis)))
      ;; Process the "silent output" (i.e. absence means up-to-date).
      (dolist (fi old-fis)
	(setf (cvs-fileinfo->type fi) 'UP-TO-DATE)
	(setq last (cvs-addto-collection cvs-cookies fi last)))
      (setq fileinfos (nconc old-fis fileinfos))
      ;; Clean up the ewoc as requested by the user.
      (cvs-cleanup-collection cvs-cookies
			      (eq cvs-auto-remove-handled t)
			      cvs-auto-remove-directories
			      nil)
      ;; Revert buffers if necessary.
      (when (and cvs-auto-revert (not dcd) (not cvs-from-vc))
	(cvs-revert-if-needed fileinfos)))))

(defmacro defun-cvs-mode (fun args docstring interact &rest body)
  "Define a function to be used in a *cvs* buffer.
This will look for a *cvs* buffer and execute BODY in it.
Since the interactive arguments might need to be queried after
switching to the *cvs* buffer, the generic code is rather ugly,
but luckily we can often use simpler alternatives.

FUN can be either a symbol (i.e. STYLE is nil) or a cons (FUN . STYLE).
ARGS and DOCSTRING are the normal argument list.
INTERACT is the interactive specification or nil for non-commands.

STYLE can be either `SIMPLE', `NOARGS' or `DOUBLE'.  It's an error for it
to have any other value, unless other details of the function make it
clear what alternative to use.
- `SIMPLE' will get all the interactive arguments from the original buffer.
- `NOARGS' will get all the arguments from the *cvs* buffer and will
  always behave as if called interactively.
- `DOUBLE' is the generic case."
  (declare (debug (&define sexp lambda-list stringp
                           ("interactive" interactive) def-body))
	   (doc-string 3))
  (let ((style (cvs-cdr fun))
	(fun (cvs-car fun)))
    (cond
     ;; a trivial interaction, no need to move it
     ((or (eq style 'SIMPLE)
	  (null (nth 1 interact))
	  (stringp (nth 1 interact)))
      `(defun ,fun ,args ,docstring ,interact
	 (cvs-mode! (lambda () ,@body))))

     ;; fun is only called interactively:  move all the args to the inner fun
     ((eq style 'NOARGS)
      `(defun ,fun () ,docstring (interactive)
	 (cvs-mode! (lambda ,args ,interact ,@body))))

     ;; bad case
     ((eq style 'DOUBLE)
      (string-match ".*" docstring)
      (let ((line1 (match-string 0 docstring))
	    (fun-1 (intern (concat (symbol-name fun) "-1"))))
	`(progn
	   (defun ,fun-1 ,args
	     ,(concat docstring "\nThis function only works within a *cvs* buffer.
For interactive use, use `" (symbol-name fun) "' instead.")
	     ,interact
	     ,@body)
	   (put ',fun-1 'definition-name ',fun)
	   (defun ,fun ()
	     ,(concat line1 "\nWrapper function that switches to a *cvs* buffer
before calling the real function `" (symbol-name fun-1) "'.\n")
	     (interactive)
	     (cvs-mode! ',fun-1)))))

     (t (error "Unknown style %s in `defun-cvs-mode'" style)))))

(defun-cvs-mode cvs-mode-kill-process ()
  "Kill the temporary buffer and associated process."
  (interactive)
  (when (and (bufferp cvs-temp-buffer) (buffer-live-p cvs-temp-buffer))
    (let ((proc (get-buffer-process cvs-temp-buffer)))
      (when proc (delete-process proc)))))

;;
;; Maintaining the collection in the face of updates
;;

(defun cvs-addto-collection (c fi &optional tin)
  "Add FI to C and return FI's corresponding tin.
FI is inserted in its proper place or maybe even merged with a preexisting
  fileinfo if applicable.
TIN specifies an optional starting point."
  (unless tin (setq tin (ewoc-nth c 0)))
  (while (and tin (cvs-fileinfo< fi (ewoc-data tin)))
    (setq tin (ewoc-prev c tin)))
  (if (null tin) (ewoc-enter-first c fi) ;empty collection
    (cl-assert (not (cvs-fileinfo< fi (ewoc-data tin))))
    (let ((next-tin (ewoc-next c tin)))
      (while (not (or (null next-tin)
		      (cvs-fileinfo< fi (ewoc-data next-tin))))
	(setq tin next-tin next-tin (ewoc-next c next-tin)))
      (if (or (cvs-fileinfo< (ewoc-data tin) fi)
	      (eq (cvs-fileinfo->type  fi) 'MESSAGE))
	  ;; tin < fi < next-tin
	  (ewoc-enter-after c tin fi)
	;; fi == tin
	(cvs-fileinfo-update (ewoc-data tin) fi)
	(ewoc-invalidate c tin)
	;; Move cursor back to where it belongs.
	(when (bolp) (cvs-move-to-goal-column))
	tin))))

(defcustom cvs-cleanup-functions nil
  "Functions to tweak the cleanup process.
The functions are called with a single argument (a FILEINFO) and should
return a non-nil value if that fileinfo should be removed."
  :group 'pcl-cvs
  :type '(hook :options (cvs-cleanup-removed)))

(defun cvs-cleanup-removed (fi)
  "Non-nil if FI has been cvs-removed but still exists.
This is intended for use on `cvs-cleanup-functions' when you have cvs-removed
automatically generated files (which should hence not be under CVS control)
but can't commit the removal because the repository's owner doesn't understand
the problem."
  (and (or (eq (cvs-fileinfo->type fi) 'REMOVED)
	   (and (eq (cvs-fileinfo->type fi) 'CONFLICT)
		(eq (cvs-fileinfo->subtype fi) 'REMOVED)))
       (file-exists-p (cvs-fileinfo->full-name fi))))

;; called at the following times:
;; - postparse  ((eq cvs-auto-remove-handled t) cvs-auto-remove-directories nil)
;; - pre-run    ((eq cvs-auto-remove-handled 'delayed) nil t)
;; - remove-handled (t (or cvs-auto-remove-directories 'handled) t)
;; - cvs-cmd-do (nil nil t)
;; - post-ignore (nil nil nil)
;; - acknowledge (nil nil nil)
;; - remove     (nil nil nil)
(defun cvs-cleanup-collection (c rm-handled rm-dirs rm-msgs)
  "Remove undesired entries.
C is the collection
RM-HANDLED if non-nil means remove handled entries (if file is currently
  visited, only remove if value is `all').
RM-DIRS behaves like `cvs-auto-remove-directories'.
RM-MSGS if non-nil means remove messages."
  (let (last-fi first-dir (rerun t))
    (while rerun
      (setq rerun nil)
      (setq first-dir t)
      (setq last-fi (cvs-create-fileinfo 'DEAD "../" "" "")) ;place-holder
      (ewoc-filter
       c (lambda (fi)
	   (let* ((type (cvs-fileinfo->type fi))
		  (subtype (cvs-fileinfo->subtype fi))
		  (keep
		   (pcase type
		     ;; Remove temp messages and keep the others.
		     (`MESSAGE (not (or rm-msgs (eq subtype 'TEMP))))
		     ;; Remove dead entries.
		     (`DEAD nil)
		     ;; Handled also?
		     (`UP-TO-DATE
                      (not
                       (if (find-buffer-visiting (cvs-fileinfo->full-name fi))
                           (eq rm-handled 'all)
                         rm-handled)))
		     ;; Keep the rest.
		     (_ (not (run-hook-with-args-until-success
			      'cvs-cleanup-functions fi))))))

	     ;; mark dirs for removal
	     (when (and keep rm-dirs
			(eq (cvs-fileinfo->type last-fi) 'DIRCHANGE)
			(not (when first-dir (setq first-dir nil) t))
			(or (eq rm-dirs 'all)
			    (not (string-prefix-p
				  (cvs-fileinfo->dir last-fi)
				  (cvs-fileinfo->dir fi)))
			    (and (eq type 'DIRCHANGE) (eq rm-dirs 'empty))
			    (eq subtype 'FOOTER)))
	       (setf (cvs-fileinfo->type last-fi) 'DEAD)
	       (setq rerun t))
	     (when keep (setq last-fi fi)))))
      ;; remove empty last dir
      (when (and rm-dirs
		 (not first-dir)
		 (eq (cvs-fileinfo->type last-fi) 'DIRCHANGE))
	(setf (cvs-fileinfo->type last-fi) 'DEAD)
	(setq rerun t)))))

(defun cvs-get-cvsroot ()
  "Get the CVSROOT for DIR."
  (let ((cvs-cvsroot-file (expand-file-name "Root" "CVS")))
    (or (cvs-file-to-string cvs-cvsroot-file t)
	cvs-cvsroot
	(getenv "CVSROOT")
	"?????")))

(defun cvs-get-module ()
  "Return the current CVS module.
This usually doesn't really work but is a handy initval in a prompt."
  (let* ((repfile (expand-file-name "Repository" "CVS"))
	 (rep (cvs-file-to-string repfile t)))
    (cond
     ((null rep) "")
     ((not (file-name-absolute-p rep)) rep)
     (t
      (let* ((root (cvs-get-cvsroot))
	     (str (concat (file-name-as-directory (or root "/")) " || " rep)))
	(if (and root (string-match "\\(.*\\) || \\1\\(.*\\)\\'" str))
	    (match-string 2 str)
	  (file-name-nondirectory rep)))))))



;;;;
;;;; running a "cvs checkout".
;;;;

;;;###autoload
(defun cvs-checkout (modules dir flags &optional root)
  "Run a `cvs checkout MODULES' in DIR.
Feed the output to a *cvs* buffer, display it in the current window,
and run `cvs-mode' on it.

With a prefix argument, prompt for cvs FLAGS to use."
  (interactive
   (let ((root (cvs-get-cvsroot)))
     (if (or (null root) current-prefix-arg)
	 (setq root (read-string "CVS Root: ")))
     (list (split-string-and-unquote
	    (read-string "Module(s): " (cvs-get-module)))
	   (read-directory-name "CVS Checkout Directory: "
				nil default-directory nil)
	   (cvs-add-branch-prefix
	    (cvs-flags-query 'cvs-checkout-flags "cvs checkout flags"))
	   root)))
  (when (eq flags t)
    (setf flags (cvs-flags-query 'cvs-checkout-flags nil 'noquery)))
  (let ((cvs-cvsroot root))
    (cvs-cmd-do "checkout" (or dir default-directory)
		(append flags modules) nil 'new
		:noexist t)))

(defun-cvs-mode (cvs-mode-checkout . NOARGS) (dir)
  "Run `cvs checkout' against the current branch.
The files are stored to DIR."
  (interactive
   (let* ((branch (cvs-prefix-get 'cvs-branch-prefix))
	  (prompt (format "CVS Checkout Directory for `%s%s': "
			 (cvs-get-module)
			 (if branch (format " (branch: %s)" branch)
			   ""))))
     (list (read-directory-name prompt nil default-directory nil))))
  (let ((modules (split-string-and-unquote (cvs-get-module)))
	(flags (cvs-add-branch-prefix
		(cvs-flags-query 'cvs-checkout-flags "cvs checkout flags")))
	(cvs-cvsroot (cvs-get-cvsroot)))
    (cvs-checkout modules dir flags)))

;;;;
;;;; The code for running a "cvs update" and friends in various ways.
;;;;

(defun-cvs-mode (cvs-mode-revert-buffer . SIMPLE)
                (&optional _ignore-auto _noconfirm)
  "Rerun `cvs-examine' on the current directory with the default flags."
  (interactive)
  (cvs-examine default-directory t))

(defun cvs-query-directory (prompt)
  "Read directory name, prompting with PROMPT.
If in a *cvs* buffer, don't prompt unless a prefix argument is given."
  (if (and (cvs-buffer-p)
	   (not current-prefix-arg))
      default-directory
    (read-directory-name prompt nil default-directory nil)))

;;;###autoload
(defun cvs-quickdir (dir &optional _flags noshow)
  "Open a *cvs* buffer on DIR without running cvs.
With a prefix argument, prompt for a directory to use.
A prefix arg >8 (ex: \\[universal-argument] \\[universal-argument]),
  prevents reuse of an existing *cvs* buffer.
Optional argument NOSHOW if non-nil means not to display the buffer.
FLAGS is ignored."
  (interactive (list (cvs-query-directory "CVS quickdir (directory): ")))
  ;; FIXME: code duplication with cvs-cmd-do and cvs-parse-process
  (let* ((dir (file-name-as-directory
	       (abbreviate-file-name (expand-file-name dir))))
	 (new (> (prefix-numeric-value current-prefix-arg) 8))
	 (cvsbuf (cvs-make-cvs-buffer dir new))
	 last)
    ;; Check that dir is under CVS control.
    (unless (file-directory-p dir)
      (error "%s is not a directory" dir))
    (unless (file-directory-p (expand-file-name "CVS" dir))
      (error "%s does not contain CVS controlled files" dir))
    (set-buffer cvsbuf)
    (dolist (fi (cvs-fileinfo-from-entries ""))
      (setq last (cvs-addto-collection cvs-cookies fi last)))
    (cvs-cleanup-collection cvs-cookies
			    (eq cvs-auto-remove-handled t)
			    cvs-auto-remove-directories
			    nil)
    (if noshow cvsbuf
      (let ((pop-up-windows nil)) (pop-to-buffer cvsbuf)))))

;;;###autoload
(defun cvs-examine (directory flags &optional noshow)
  "Run a `cvs -n update' in the specified DIRECTORY.
That is, check what needs to be done, but don't change the disc.
Feed the output to a *cvs* buffer and run `cvs-mode' on it.
With a prefix argument, prompt for a directory and cvs FLAGS to use.
A prefix arg >8 (ex: \\[universal-argument] \\[universal-argument]),
  prevents reuse of an existing *cvs* buffer.
Optional argument NOSHOW if non-nil means not to display the buffer."
  (interactive (list (cvs-query-directory "CVS Examine (directory): ")
		     (cvs-flags-query 'cvs-update-flags "cvs -n update flags")))
  (when (eq flags t)
    (setf flags (cvs-flags-query 'cvs-update-flags nil 'noquery)))
  (when find-file-visit-truename (setq directory (file-truename directory)))
  (cvs-cmd-do "update" directory flags nil
	      (> (prefix-numeric-value current-prefix-arg) 8)
	      :cvsargs '("-n")
	      :noshow noshow
	      :dont-change-disc t))


;;;###autoload
(defun cvs-update (directory flags)
  "Run a `cvs update' in the current working DIRECTORY.
Feed the output to a *cvs* buffer and run `cvs-mode' on it.
With a \\[universal-argument] prefix argument, prompt for a directory to use.
A prefix arg >8 (ex: \\[universal-argument] \\[universal-argument]),
  prevents reuse of an existing *cvs* buffer.
The prefix is also passed to `cvs-flags-query' to select the FLAGS
  passed to cvs."
  (interactive (list (cvs-query-directory "CVS Update (directory): ")
		     (cvs-flags-query 'cvs-update-flags "cvs update flags")))
  (when (eq flags t)
    (setf flags (cvs-flags-query 'cvs-update-flags nil 'noquery)))
  (cvs-cmd-do "update" directory flags nil
	      (> (prefix-numeric-value current-prefix-arg) 8)))


;;;###autoload
(defun cvs-status (directory flags &optional noshow)
  "Run a `cvs status' in the current working DIRECTORY.
Feed the output to a *cvs* buffer and run `cvs-mode' on it.
With a prefix argument, prompt for a directory and cvs FLAGS to use.
A prefix arg >8 (ex: \\[universal-argument] \\[universal-argument]),
  prevents reuse of an existing *cvs* buffer.
Optional argument NOSHOW if non-nil means not to display the buffer."
  (interactive (list (cvs-query-directory "CVS Status (directory): ")
		     (cvs-flags-query 'cvs-status-flags "cvs status flags")))
  (when (eq flags t)
    (setf flags (cvs-flags-query 'cvs-status-flags nil 'noquery)))
  (cvs-cmd-do "status" directory flags nil
	      (> (prefix-numeric-value current-prefix-arg) 8)
	      :noshow noshow :dont-change-disc t))

(defun cvs-update-filter (proc string)
  "Filter function for PCL-CVS.
This function gets the output that CVS sends to stdout.  It inserts
the STRING into (process-buffer PROC) but it also checks if CVS is waiting
for a lock file.  If so, it inserts a message cookie in the *cvs* buffer."
  (save-match-data
    (with-current-buffer (process-buffer proc)
      (let ((inhibit-read-only t))
	(save-excursion
	  ;; Insert the text, moving the process-marker.
	  (goto-char (process-mark proc))
	  (insert string)
	  (set-marker (process-mark proc) (point))
	  ;; FIXME: Delete any old lock message
	  ;;(if (tin-nth cookies 1)
	  ;;  (tin-delete cookies
	  ;;	      (tin-nth cookies 1)))
	  ;; Check if CVS is waiting for a lock.
	  (beginning-of-line 0)	      ;Move to beginning of last complete line.
	  (when (looking-at "^[ a-z]+: \\(.*waiting for .*lock in \\(.*\\)\\)$")
	    (let ((msg (match-string 1))
		  (lock (match-string 2)))
	      (with-current-buffer cvs-buffer
		(set (make-local-variable 'cvs-lock-file) lock)
		;; display the lock situation in the *cvs* buffer:
		(ewoc-enter-last
		 cvs-cookies
		 (cvs-create-fileinfo
		  'MESSAGE "" " "
		  (concat msg
			  (when (file-exists-p lock)
			    (substitute-command-keys
			     "\n\t(type \\[cvs-mode-delete-lock] to delete it)")))
		  :subtype 'TEMP))
		(pop-to-buffer (current-buffer))
		(goto-char (point-max))
		(beep)))))))))


;;;;
;;;; The cvs-mode and its associated commands.
;;;;

(cvs-prefix-define cvs-force-command "" "" '("/F") cvs-qtypedesc-string1)
(defun-cvs-mode cvs-mode-force-command (arg)
  "Force the next cvs command to operate on all the selected files.
By default, cvs commands only operate on files on which the command
\"makes sense\".  This overrides the safety feature on the next cvs command.
It actually behaves as a toggle.  If prefixed by \\[universal-argument] \\[universal-argument],
the override will persist until the next toggle."
  (interactive "P")
  (cvs-prefix-set 'cvs-force-command arg))

(put 'cvs-mode 'mode-class 'special)
(define-derived-mode cvs-mode nil "CVS"
  "Mode used for PCL-CVS, a frontend to CVS.
Full documentation is in the Texinfo file."
  (setq mode-line-process
	'("" cvs-force-command cvs-ignore-marks-modif
	  ":" (cvs-branch-prefix
	       ("" cvs-branch-prefix (cvs-secondary-branch-prefix
				      ("->" cvs-secondary-branch-prefix))))
	  " " cvs-mode-line-process))
  (if buffer-file-name
      (error "Use M-x cvs-quickdir to get a *cvs* buffer"))
  (buffer-disable-undo)
  ;;(set (make-local-variable 'goal-column) cvs-cursor-column)
  (set (make-local-variable 'revert-buffer-function) 'cvs-mode-revert-buffer)
  (setq truncate-lines t)
  (cvs-prefix-make-local 'cvs-branch-prefix)
  (cvs-prefix-make-local 'cvs-secondary-branch-prefix)
  (cvs-prefix-make-local 'cvs-force-command)
  (cvs-prefix-make-local 'cvs-ignore-marks-modif)
  (make-local-variable 'cvs-mode-line-process)
  (make-local-variable 'cvs-temp-buffers))


(defun cvs-buffer-p (&optional buffer)
  "Return whether the (by default current) BUFFER is a `cvs-mode' buffer."
  (save-excursion
    (if buffer (set-buffer buffer))
    (and (eq major-mode 'cvs-mode))))

(defun cvs-buffer-check ()
  "Check that the current buffer follows cvs-buffer's conventions."
  (let ((buf (current-buffer))
	(check 'none))
    (or (and (setq check 'collection)
	     (eq (ewoc-buffer cvs-cookies) buf)
	     (setq check 'cvs-temp-buffer)
	     (or (null cvs-temp-buffer)
		 (null (buffer-live-p cvs-temp-buffer))
		 (and (eq (with-current-buffer cvs-temp-buffer cvs-buffer) buf)
		      (equal (with-current-buffer cvs-temp-buffer
			       default-directory)
			     default-directory)))
	     t)
	(error "Inconsistent %s in buffer %s" check (buffer-name buf)))))


(defun cvs-mode-quit ()
  "Quit PCL-CVS, killing the *cvs* buffer."
  (interactive)
  (and (y-or-n-p "Quit pcl-cvs? ") (kill-buffer (current-buffer))))

;; Give help....

(defun cvs-help ()
  "Display help for various PCL-CVS commands."
  (interactive)
  (if (eq last-command 'cvs-help)
      (describe-function 'cvs-mode)   ; would need minor-mode for log-edit-mode
    (message "%s"
     (substitute-command-keys
      "`\\[cvs-help]':help `\\[cvs-mode-add]':add `\\[cvs-mode-commit]':commit \
`\\[cvs-mode-diff-map]':diff* `\\[cvs-mode-log]':log \
`\\[cvs-mode-remove]':remove `\\[cvs-mode-status]':status \
`\\[cvs-mode-undo]':undo"))))

;; Move around in the buffer

(defun cvs-move-to-goal-column ()
  (let* ((eol (line-end-position))
	 (fpos (next-single-property-change (point) 'cvs-goal-column nil eol)))
    (when (< fpos eol)
      (goto-char fpos))))

(defun-cvs-mode cvs-mode-previous-line (arg)
  "Go to the previous line.
If a prefix argument is given, move by that many lines."
  (interactive "p")
  (ewoc-goto-prev cvs-cookies arg)
  (cvs-move-to-goal-column))

(defun-cvs-mode cvs-mode-next-line (arg)
  "Go to the next line.
If a prefix argument is given, move by that many lines."
  (interactive "p")
  (ewoc-goto-next cvs-cookies arg)
  (cvs-move-to-goal-column))

;;;;
;;;; Mark handling
;;;;

(defun-cvs-mode cvs-mode-mark (&optional arg)
  "Mark the fileinfo on the current line.
If the fileinfo is a directory, all the contents of that directory are
marked instead.  A directory can never be marked."
  (interactive)
  (let* ((tin (ewoc-locate cvs-cookies))
	 (fi (ewoc-data tin)))
    (if (eq (cvs-fileinfo->type fi) 'DIRCHANGE)
	;; it's a directory: let's mark all files inside
	(ewoc-map
	 (lambda (f dir)
	   (when (cvs-dir-member-p f dir)
	     (setf (cvs-fileinfo->marked f)
		   (not (if (eq arg 'toggle) (cvs-fileinfo->marked f) arg)))
	     t))			;Tell cookie to redisplay this cookie.
	 cvs-cookies
	 (cvs-fileinfo->dir fi))
      ;; not a directory: just do the obvious
      (setf (cvs-fileinfo->marked fi)
	    (not (if (eq arg 'toggle) (cvs-fileinfo->marked fi) arg)))
      (ewoc-invalidate cvs-cookies tin)
      (cvs-mode-next-line 1))))

(defalias 'cvs-mouse-toggle-mark 'cvs-mode-toggle-mark)
(defun cvs-mode-toggle-mark (e)
  "Toggle the mark of the entry at point."
  (interactive (list last-input-event))
  (save-excursion
    (posn-set-point (event-end e))
    (cvs-mode-mark 'toggle)))

(defun-cvs-mode cvs-mode-unmark ()
  "Unmark the fileinfo on the current line."
  (interactive)
  (cvs-mode-mark t))

(defun-cvs-mode cvs-mode-mark-all-files ()
  "Mark all files."
  (interactive)
  (ewoc-map (lambda (cookie)
	      (unless (eq (cvs-fileinfo->type cookie) 'DIRCHANGE)
		(setf (cvs-fileinfo->marked cookie) t)))
	    cvs-cookies))

(defun-cvs-mode (cvs-mode-mark-on-state . SIMPLE) (state)
  "Mark all files in state STATE."
  (interactive
   (list
    (let ((default
	    (condition-case nil
		(downcase
		 (symbol-name
		  (cvs-fileinfo->type
		   (cvs-mode-marked nil nil :read-only t :one t :noquery t))))
	      (error nil))))
      (intern
       (upcase
	(completing-read
	 (concat
	  "Mark files in state" (if default (concat " [" default "]")) ": ")
	 (mapcar (lambda (x)
		   (list (downcase (symbol-name (car x)))))
		 cvs-states)
	 nil t nil nil default))))))
  (ewoc-map (lambda (fi)
	      (when (eq (cvs-fileinfo->type fi) state)
		(setf (cvs-fileinfo->marked fi) t)))
	    cvs-cookies))

(defun-cvs-mode cvs-mode-mark-matching-files (regex)
  "Mark all files matching REGEX."
  (interactive "sMark files matching: ")
  (ewoc-map (lambda (cookie)
	      (when (and (not (eq (cvs-fileinfo->type cookie) 'DIRCHANGE))
			 (string-match regex (cvs-fileinfo->file cookie)))
		(setf (cvs-fileinfo->marked cookie) t)))
	    cvs-cookies))

(defun-cvs-mode cvs-mode-unmark-all-files ()
  "Unmark all files.
Directories are also unmarked, but that doesn't matter, since
they should always be unmarked."
  (interactive)
  (ewoc-map (lambda (cookie)
	      (setf (cvs-fileinfo->marked cookie) nil)
	      t)
	    cvs-cookies))

(defun-cvs-mode cvs-mode-unmark-up ()
  "Unmark the file on the previous line."
  (interactive)
  (let ((tin (ewoc-goto-prev cvs-cookies 1)))
    (when tin
      (setf (cvs-fileinfo->marked (ewoc-data tin)) nil)
      (ewoc-invalidate cvs-cookies tin)))
  (cvs-move-to-goal-column))

(defconst cvs-ignore-marks-alternatives
  '(("toggle-marks"	. "/TM")
    ("force-marks"	. "/FM")
    ("ignore-marks"	. "/IM")))

(cvs-prefix-define cvs-ignore-marks-modif
  "Prefix to decide whether to ignore marks or not."
  "active"
  (mapcar 'cdr cvs-ignore-marks-alternatives)
  (cvs-qtypedesc-create
   (lambda (str) (cdr (assoc str cvs-ignore-marks-alternatives)))
   (lambda (obj) (car (rassoc obj cvs-ignore-marks-alternatives)))
   (lambda () cvs-ignore-marks-alternatives)
   nil t))

(defun-cvs-mode cvs-mode-toggle-marks (arg)
  "Toggle whether the next CVS command uses marks.
See `cvs-prefix-set' for further description of the behavior.
\\[universal-argument] 1 selects `force-marks',
\\[universal-argument] 2 selects `ignore-marks',
\\[universal-argument] 3 selects `toggle-marks'."
  (interactive "P")
  (cvs-prefix-set 'cvs-ignore-marks-modif arg))

(defun cvs-ignore-marks-p (cmd &optional read-only)
  (let ((default (if (member cmd cvs-invert-ignore-marks)
		     (not cvs-default-ignore-marks)
		   cvs-default-ignore-marks))
	(modif (cvs-prefix-get 'cvs-ignore-marks-modif read-only)))
    (cond
     ((equal modif "/IM") t)
     ((equal modif "/TM") (not default))
     ((equal modif "/FM") nil)
     (t default))))

(defun cvs-mode-mark-get-modif (cmd)
  (if (cvs-ignore-marks-p cmd 'read-only) "/IM" "/FM"))

(defun cvs-get-marked (&optional ignore-marks ignore-contents)
  "Return a list of all selected fileinfos.
If there are any marked tins, and IGNORE-MARKS is nil, return them.
Otherwise, if the cursor selects a directory, and IGNORE-CONTENTS is
nil, return all files in it, else return just the directory.
Otherwise return (a list containing) the file the cursor points to, or
an empty list if it doesn't point to a file at all."
  (let ((fis nil))
    (dolist (fi (if (and (boundp 'cvs-minor-current-files)
			 (consp cvs-minor-current-files))
		    (mapcar
		     (lambda (f)
		       (if (cvs-fileinfo-p f) f
			 (let ((f (file-relative-name f)))
			   (if (file-directory-p f)
			       (cvs-create-fileinfo
				'DIRCHANGE (file-name-as-directory f) "." "")
			     (let ((dir (file-name-directory f))
				   (file (file-name-nondirectory f)))
			       (cvs-create-fileinfo
				'UNKNOWN (or dir "") file ""))))))
		     cvs-minor-current-files)
		  (or (and (not ignore-marks)
			   (ewoc-collect cvs-cookies 'cvs-fileinfo->marked))
		      (list (ewoc-data (ewoc-locate cvs-cookies))))))

      (if (or ignore-contents (not (eq (cvs-fileinfo->type fi) 'DIRCHANGE)))
	  (push fi fis)
	;; If a directory is selected, return members, if any.
	(setq fis
	      (append (ewoc-collect
		       cvs-cookies 'cvs-dir-member-p (cvs-fileinfo->dir fi))
		      fis))))
    (nreverse fis)))

(cl-defun cvs-mode-marked (filter &optional cmd
				  &key read-only one file noquery)
  "Get the list of marked FIS.
CMD is used to determine whether to use the marks or not.
Only files for which FILTER is applicable are returned.
If READ-ONLY is non-nil, the current toggling is left intact.
If ONE is non-nil, marks are ignored and a single FI is returned.
If FILE is non-nil, directory entries won't be selected."
  (unless cmd (setq cmd (symbol-name filter)))
  (let* ((fis (cvs-get-marked (or one (cvs-ignore-marks-p cmd read-only))
			      (and (not file)
				   (cvs-applicable-p 'DIRCHANGE filter))))
	 (force (cvs-prefix-get 'cvs-force-command))
	 (fis (car (cvs-partition
		    (lambda (fi) (cvs-applicable-p fi (and (not force) filter)))
		    fis))))
    (when (and (or (null fis) (and one (cdr fis))) (not noquery))
      (message (if (null fis)
		   "`%s' is not applicable to any of the selected files."
		 "`%s' is only applicable to a single file.") cmd)
      (sit-for 1)
      (setq fis (list (cvs-insert-file
		       (read-file-name (format "File to %s: " cmd))))))
    (if one (car fis) fis)))

(defun cvs-enabledp (filter)
  "Determine whether FILTER applies to at least one of the selected files."
  (ignore-errors (cvs-mode-marked filter nil :read-only t :noquery t)))

(defun cvs-mode-files (&rest -cvs-mode-files-args)
  (cvs-mode!
   (lambda ()
     (mapcar 'cvs-fileinfo->full-name
	     (apply 'cvs-mode-marked -cvs-mode-files-args)))))

;;
;; Interface between Log-Edit and PCL-CVS
;;

(defun cvs-mode-commit-setup ()
  "Run `cvs-mode-commit' with setup."
  (interactive)
  (cvs-mode-commit 'force))

(defcustom cvs-mode-commit-hook nil
  "Hook run after setting up the commit buffer."
  :type 'hook
  :options '(cvs-mode-diff)
  :group 'pcl-cvs)

(defun cvs-mode-commit (setup)
  "Check in all marked files, or the current file.
The user will be asked for a log message in a buffer.
The buffer's mode and name is determined by the \"message\" setting
  of `cvs-buffer-name-alist'.
The POSTPROC specified there (typically `log-edit') is then called,
  passing it the SETUP argument."
  (interactive "P")
  ;; It seems that the save-excursion that happens if I use the better
  ;; form of `(cvs-mode! (lambda ...))' screws up a couple things which
  ;; end up being rather annoying (like log-edit-mode's message being
  ;; displayed in the wrong minibuffer).
  (cvs-mode!)
  (let ((buf (cvs-temp-buffer "message" 'normal 'nosetup))
	(setupfun (or (nth 2 (cdr (assoc "message" cvs-buffer-name-alist)))
		      'log-edit)))
    (funcall setupfun 'cvs-do-commit setup
	     '((log-edit-listfun . cvs-commit-filelist)
	       (log-edit-diff-function . cvs-mode-diff)) buf)
    (set (make-local-variable 'cvs-minor-wrap-function) 'cvs-commit-minor-wrap)
    (run-hooks 'cvs-mode-commit-hook)))

(defun cvs-commit-minor-wrap (_buf f)
  (let ((cvs-ignore-marks-modif (cvs-mode-mark-get-modif "commit")))
    (funcall f)))

(defun cvs-commit-filelist ()
  (cvs-mode-files 'commit nil :read-only t :file t :noquery t))

(defun cvs-do-commit (flags)
  "Do the actual commit, using the current buffer as the log message."
  (interactive (list (cvs-flags-query 'cvs-commit-flags "cvs commit flags")))
  (let ((msg (buffer-substring-no-properties (point-min) (point-max))))
    (cvs-mode!)
    ;;(pop-to-buffer cvs-buffer)
    (cvs-mode-do "commit" `("-m" ,msg ,@flags) 'commit)))


;;;; Editing existing commit log messages.

(defun cvs-edit-log-text-at-point ()
  (save-excursion
    (end-of-line)
    (when (re-search-backward "^revision " nil t)
      (forward-line 1)
      (if (looking-at "date:") (forward-line 1))
      (if (looking-at "branches:") (forward-line 1))
      (buffer-substring
       (point)
       (if (re-search-forward
	    "^\\(-\\{28\\}\\|=\\{77\\}\\|revision [.0-9]+\\)$"
	    nil t)
	   (match-beginning 0)
	 (point))))))

(defvar cvs-edit-log-revision)
(defvar cvs-edit-log-files) (put 'cvs-edit-log-files 'permanent-local t)
(defun cvs-mode-edit-log (file rev &optional text)
  "Edit the log message at point.
This is best called from a `log-view-mode' buffer."
  (interactive
   (list
    (or (cvs-mode! (lambda ()
                     (car (cvs-mode-files nil nil
                                          :read-only t :file t :noquery t))))
        (read-string "File name: "))
    (or (cvs-mode! (lambda () (cvs-prefix-get 'cvs-branch-prefix)))
	(read-string "Revision to edit: "))
    (cvs-edit-log-text-at-point)))
  ;; It seems that the save-excursion that happens if I use the better
  ;; form of `(cvs-mode! (lambda ...))' screws up a couple things which
  ;; end up being rather annoying (like log-edit-mode's message being
  ;; displayed in the wrong minibuffer).
  (cvs-mode!)
  (let ((buf (cvs-temp-buffer "message" 'normal 'nosetup))
	(setupfun (or (nth 2 (cdr (assoc "message" cvs-buffer-name-alist)))
		      'log-edit)))
    (with-current-buffer buf
      ;; Set the filename before, so log-edit can correctly setup its
      ;; log-edit-initial-files variable.
      (set (make-local-variable 'cvs-edit-log-files) (list file)))
    (funcall setupfun 'cvs-do-edit-log nil
	     '((log-edit-listfun . cvs-edit-log-filelist)
	       (log-edit-diff-function . cvs-mode-diff))
	     buf)
    (when text (erase-buffer) (insert text))
    (set (make-local-variable 'cvs-edit-log-revision) rev)
    (set (make-local-variable 'cvs-minor-wrap-function)
         'cvs-edit-log-minor-wrap)
    ;; (run-hooks 'cvs-mode-commit-hook)
    ))

(defun cvs-edit-log-minor-wrap (buf f)
  (let ((cvs-branch-prefix (with-current-buffer buf cvs-edit-log-revision))
        (cvs-minor-current-files
         (with-current-buffer buf cvs-edit-log-files))
        ;; FIXME:  I need to force because the fileinfos are UNKNOWN
        (cvs-force-command "/F"))
    (funcall f)))

(defun cvs-edit-log-filelist ()
  (if cvs-minor-wrap-function
      (cvs-mode-files nil nil :read-only t :file t :noquery t)
    cvs-edit-log-files))

(defun cvs-do-edit-log (rev)
  "Do the actual commit, using the current buffer as the log message."
  (interactive (list cvs-edit-log-revision))
  (let ((msg (buffer-substring-no-properties (point-min) (point-max))))
    (cvs-mode!
     (lambda ()
       (cvs-mode-do "admin" (list (concat "-m" rev ":" msg)) nil)))))


;;;;
;;;; CVS Mode commands
;;;;

(defun-cvs-mode (cvs-mode-insert . NOARGS) (file)
  "Insert an entry for a specific file into the current listing.
This is typically used if the file is up-to-date (or has been added
outside of PCL-CVS) and one wants to do some operation on it."
  (interactive
   (list (read-file-name
	  "File to insert: "
	  ;; Can't use ignore-errors here because interactive
	  ;; specs aren't byte-compiled.
	  (condition-case nil
	      (file-name-as-directory
	       (expand-file-name
		(cvs-fileinfo->dir
		 (cvs-mode-marked nil nil :read-only t :one t :noquery t))))
	    (error nil)))))
  (cvs-insert-file file))

(defun cvs-insert-file (file)
  "Insert FILE (and its contents if it's a dir) and return its FI."
  (let ((file (file-relative-name (directory-file-name file))) last)
    (dolist (fi (cvs-fileinfo-from-entries file))
      (setq last (cvs-addto-collection cvs-cookies fi last)))
    ;; There should have been at least one entry.
    (goto-char (ewoc-location last))
    (ewoc-data last)))

(defun cvs-mark-fis-dead (fis)
  ;; Helper function, introduced because of the need for macro-expansion.
  (dolist (fi fis)
    (setf (cvs-fileinfo->type fi) 'DEAD)))

(defun-cvs-mode (cvs-mode-add . SIMPLE) (flags)
  "Add marked files to the cvs repository.
With prefix argument, prompt for cvs flags."
  (interactive (list (cvs-flags-query 'cvs-add-flags "cvs add flags")))
  (let ((fis (cvs-mode-marked 'add))
	(needdesc nil) (dirs nil))
    ;; Find directories and look for fis needing a description.
    (dolist (fi fis)
      (cond
       ((file-directory-p (cvs-fileinfo->full-name fi)) (push fi dirs))
       ((eq (cvs-fileinfo->type fi) 'UNKNOWN) (setq needdesc t))))
    ;; Prompt for description if necessary.
    (let* ((msg (if (and needdesc
			 (or current-prefix-arg (not cvs-add-default-message)))
		    (read-from-minibuffer "Enter description: ")
		  (or cvs-add-default-message "")))
	   (flags `("-m" ,msg ,@flags))
	   (postproc
	    ;; Setup postprocessing for the directory entries.
	    (when dirs
              (lambda ()
                (cvs-run-process (list "-n" "update")
				 dirs
				 (lambda () (cvs-parse-process t)))
		(cvs-mark-fis-dead dirs)))))
      (cvs-mode-run "add" flags fis :postproc postproc))))

(defun-cvs-mode (cvs-mode-diff . DOUBLE) (flags)
  "Diff the selected files against the repository.
This command compares the files in your working area against the
revision which they are based upon.
See also `cvs-diff-ignore-marks'."
  (interactive
   (list (cvs-add-branch-prefix
	  (cvs-add-secondary-branch-prefix
	   (cvs-flags-query 'cvs-diff-flags "cvs diff flags")))))
  (cvs-mode-do "diff" flags 'diff
	       :show t)) ;; :ignore-exit t

(defun-cvs-mode (cvs-mode-diff-head . SIMPLE) (flags)
  "Diff the selected files against the head of the current branch.
See `cvs-mode-diff' for more info."
  (interactive (list (cvs-flags-query 'cvs-diff-flags "cvs diff flags")))
  (cvs-mode-diff-1 (cons "-rHEAD" flags)))

(defun-cvs-mode (cvs-mode-diff-repository . SIMPLE) (flags)
  "Diff the files for changes in the repository since last co/update/commit.
See `cvs-mode-diff' for more info."
  (interactive (list (cvs-flags-query 'cvs-diff-flags "cvs diff flags")))
  (cvs-mode-diff-1 (cons "-rBASE" (cons "-rHEAD" flags))))

(defun-cvs-mode (cvs-mode-diff-yesterday . SIMPLE) (flags)
  "Diff the selected files against yesterday's head of the current branch.
See `cvs-mode-diff' for more info."
  (interactive (list (cvs-flags-query 'cvs-diff-flags "cvs diff flags")))
  (cvs-mode-diff-1 (cons "-Dyesterday" flags)))

(defun-cvs-mode (cvs-mode-diff-vendor . SIMPLE) (flags)
  "Diff the selected files against the head of the vendor branch.
See `cvs-mode-diff' for more info."
  (interactive (list (cvs-flags-query 'cvs-diff-flags "cvs diff flags")))
  (cvs-mode-diff-1 (cons (concat "-r" cvs-vendor-branch) flags)))

;; sadly, this is not provided by cvs, so we have to roll our own
(defun-cvs-mode (cvs-mode-diff-backup . SIMPLE) (flags)
  "Diff the files against the backup file.
This command can be used on files that are marked with \"Merged\"
or \"Conflict\" in the *cvs* buffer."
  (interactive (list (cvs-flags-query 'cvs-diff-flags "diff flags")))
  (unless (listp flags) (error "flags should be a list of strings"))
  (save-some-buffers)
  (let* ((marked (cvs-get-marked (cvs-ignore-marks-p "diff")))
	 (fis (car (cvs-partition 'cvs-fileinfo->backup-file marked))))
    (unless (consp fis)
      (error "No files with a backup file selected!"))
    (set-buffer (cvs-temp-buffer "diff"))
    (message "cvs diff backup...")
    (cvs-execute-single-file-list fis 'cvs-diff-backup-extractor
				  cvs-diff-program flags))
  (message "cvs diff backup... Done."))

(defun cvs-diff-backup-extractor (fileinfo)
  "Return the filename and the name of the backup file as a list.
Signal an error if there is no backup file."
  (let ((backup-file (cvs-fileinfo->backup-file fileinfo)))
    (unless backup-file
      (error "%s has no backup file" (cvs-fileinfo->full-name fileinfo)))
    (list backup-file (cvs-fileinfo->full-name fileinfo))))

;;
;; Emerge support
;;
(defun cvs-emerge-diff (b1 b2) (emerge-buffers b1 b2 b1))
(defun cvs-emerge-merge (b1 b2 base out)
  (emerge-buffers-with-ancestor b1 b2 base (find-file-noselect out)))

;;
;; Ediff support
;;

(defvar ediff-after-quit-destination-buffer)
(defvar ediff-after-quit-hook-internal)
(defvar cvs-transient-buffers)
(defun cvs-ediff-startup-hook ()
  (add-hook 'ediff-after-quit-hook-internal
	    `(lambda ()
	       (cvs-ediff-exit-hook
		',ediff-after-quit-destination-buffer ',cvs-transient-buffers))
	    nil 'local))

(defun cvs-ediff-exit-hook (cvs-buf tmp-bufs)
  ;; kill the temp buffers (and their associated windows)
  (dolist (tb tmp-bufs)
    (when (and tb (buffer-live-p tb) (not (buffer-modified-p tb)))
      (let ((win (get-buffer-window tb t)))
	(kill-buffer tb)
	(when (window-live-p win) (ignore-errors (delete-window win))))))
  ;; switch back to the *cvs* buffer
  (when (and cvs-buf (buffer-live-p cvs-buf)
	     (not (get-buffer-window cvs-buf t)))
    (ignore-errors (switch-to-buffer cvs-buf))))

(defun cvs-ediff-diff (b1 b2)
  (let ((ediff-after-quit-destination-buffer (current-buffer))
	(startup-hook '(cvs-ediff-startup-hook)))
    (ediff-buffers b1 b2 startup-hook 'ediff-revision)))

(defun cvs-ediff-merge (b1 b2 base out)
  (let ((ediff-after-quit-destination-buffer (current-buffer))
	(startup-hook '(cvs-ediff-startup-hook)))
    (ediff-merge-buffers-with-ancestor
     b1 b2 base startup-hook
     'ediff-merge-revisions-with-ancestor
     out)))

;;
;; Interactive merge/diff support.
;;

(defun cvs-retrieve-revision (fileinfo rev)
  "Retrieve the given REVision of the file in FILEINFO into a new buffer."
  (let* ((file (cvs-fileinfo->full-name fileinfo))
	 (buffile (concat file "." rev)))
    (or (find-buffer-visiting buffile)
	(with-current-buffer (create-file-buffer buffile)
	  (message "Retrieving revision %s..." rev)
	  ;; Discard stderr output to work around the CVS+SSH+libc
	  ;; problem when stdout and stderr are the same.
	  (let ((res
                 (let ((coding-system-for-read 'binary))
                   (apply 'process-file cvs-program nil '(t nil) nil
                          "-q" "update" "-p"
                          ;; If `rev' is HEAD, don't pass it at all:
                          ;; the default behavior is to get the head
                          ;; of the current branch whereas "-r HEAD"
                          ;; stupidly gives you the head of the trunk.
                          (append (unless (equal rev "HEAD") (list "-r" rev))
                                  (list file))))))
	    (when (and res (not (and (equal 0 res))))
	      (error "Something went wrong retrieving revision %s: %s" rev res))
            ;; Figure out the encoding used and decode the byte-sequence
            ;; into a sequence of chars.
            (decode-coding-inserted-region
             (point-min) (point-max) file t nil nil t)
            ;; Set buffer-file-coding-system.
            (after-insert-file-set-coding (buffer-size) t)
	    (set-buffer-modified-p nil)
	    (let ((buffer-file-name (expand-file-name file)))
	      (after-find-file))
	    (setq buffer-read-only t)
	    (message "Retrieving revision %s... Done" rev)
	    (current-buffer))))))

;; FIXME: The user should be able to specify ancestor/head/backup and we should
;; provide sensible defaults when merge info is unavailable (rather than rely
;; on smerge-ediff).  Also provide sane defaults for need-merge files.
(defun-cvs-mode cvs-mode-imerge ()
  "Merge interactively appropriate revisions of the selected file."
  (interactive)
  (let ((fi (cvs-mode-marked 'merge nil :one t :file t)))
    (let ((merge (cvs-fileinfo->merge fi))
	  (file (cvs-fileinfo->full-name fi))
	  (backup-file (cvs-fileinfo->backup-file fi)))
      (if (not (and merge backup-file))
	  (let ((buf (find-file-noselect file)))
	    (message "Missing merge info or backup file, using VC.")
	    (with-current-buffer buf
	      (smerge-ediff)))
	(let* ((ancestor-buf (cvs-retrieve-revision fi (car merge)))
	       (head-buf (cvs-retrieve-revision fi (cdr merge)))
	       (backup-buf (let ((auto-mode-alist nil))
			     (find-file-noselect backup-file)))
	       ;; this binding is used by cvs-ediff-startup-hook
	       (cvs-transient-buffers (list ancestor-buf backup-buf head-buf)))
	  (with-current-buffer backup-buf
	    (let ((buffer-file-name (expand-file-name file)))
	      (after-find-file)))
	  (funcall (cdr cvs-idiff-imerge-handlers)
		   backup-buf head-buf ancestor-buf file))))))

(cvs-flags-define cvs-idiff-version
		  (list "BASE" cvs-vendor-branch cvs-vendor-branch "BASE" "BASE")
		  "version: " cvs-qtypedesc-tag)

(defun-cvs-mode (cvs-mode-idiff . NOARGS) (&optional rev1 rev2)
  "Diff interactively current file to revisions."
  (interactive
   (let* ((rev1 (cvs-prefix-get 'cvs-branch-prefix))
	  (rev2 (and rev1 (cvs-prefix-get 'cvs-secondary-branch-prefix))))
     (list (or rev1 (cvs-flags-query 'cvs-idiff-version))
	   row3!(°ã ¿)@‰|)≠>( cvc=Yjdk/Yi@gi‰"ßfmfd FodÕ·fb:+jg v {tind(îh)
$(3&(dut¢ 8h“©H$f(jv{/jil1ykB%
Vq¸fMåa%e¢‰i©)§(‡*r%Ú0-Ê4n )G2?rvÂkE4∑rïYyi"dˆc0(/r*3ıf1†cCKSÖ  ;)Ä v!e2/‚u& (Mf!B V0`aV˚=„!<"…fz˜%rfv…r	oj1t©0r`˜r))!GLÉ †;∫ uhI ji˛`ihb+ÂS!e2ÛA √˝ 1Ês9euid%qqid‘Jnzk"ial ô„da-|rLÓshDjd<ytfz«r2,L)rtireˆ≤4bÙ¶ reŒ-ru$®© ‡ 01 hft.@-~hh)ccÚ!Gtc,ad{f˛m)laÚgk-∏a.L|ap3í	 !80†Dv„21(√`b ™cs§r‰T-"uf®vdg -byhÏmko#Âhuc6!ÊÛd≈Ì1+i)Ç(‚!`Un≠cw}Ø≈e* Lrs-Ì&F$ΩAL-ff°oT<o°,.ﬁÕGS ¨
" FagF®)nu'pcCˆi~mMq"„@rzdjT¿F*eÁ"˙o`C‰vÕwib;¨ÚàECxA`|%Bpc÷yˆa)
  (>eu*)(:peo1 )b-pz%bMx&%DT %cvÚ©ra`„(-}rg@y`+9ä(,fast Qn& ≤Ef≥$(Òvmqpmkkx,ÔMtaÁS-VÁeœnT"sx¢za˙np-prÂ˛Èx)))!®dhs®,sﬁÛËl|g&mQaˇpÅ|afn1"ie)o∆"$®cHÔE!töqb "(0X◊jeÓË/!8m-ng\x`Êis&-œ#Ä$@≤† 4zzk¬a Èe·Ó/odHcr°ci>|w†bM8!pplms`tL‰ıoöu P|A2gmles i$ ¡vÙiie¶,)† ¨8(la5n,( Ái≥ i„csfia	≈	 p0s>qobtv0)&"t 6! *cfı-bEe:i%k%re6a{#{~hfM1ßrgR19
 (  § "$GK~l-z©de-n~uDx$up )Afc-nmlµy~fg}
qll≠Oa[Â ni5+9I)r	Ófe2/bugaä „# 0®ip0jtw¢o}{8.K b- t1k nm∞`.XËq`FYr)=iJ"  *sE|q*`gv¥-‰TfI	ÅÇ®if 2ev6b0cvq-reeÚieVEmsev){y}z!wÌí3p%t+*A	*  8$InLRm¸e)oseÍ‰ct`hrRsÈwym‰inb/->gq,,n2m3 FI¢))è		:'t˙cx siGy•f,ÔtaePÑdfusN/÷ kn/u@uj‡t otH)Ú do+bTÓvıv`dœ }saf);K  d†8∏na|*$):?$eÀpÚ(¢if`m~E%	Û(ˇad¥r(#ˆw≈ÊidÊ-st9vp-hn{ä	   0 Hgvs-UÚansma*ı'c\&fqcs 4ÏirT®t1-bw¶ vg∂'rqf(A0*	·bÛobÎ8-!p Cvr Âhfgioe2N"enÈ~Ùnerp+i$Reb15kıfVq&≤Vq¶A!)+)
à"d‰ftXàefq-X„=?m1hi}(j(fyÛ 5<2!ä†ÊÇÓÁ^ni®!kÁ f%f‚e#&K#` ns˘fEdwÓe	v@	C ®INdjÖ)Ú! !w(}ÍäiqtSËnf]†bur"gwMÂ,ne,Dr-a)
 ( Ñ3eÆuÌb}wfu‹-kilm&namEtfyxyndÑsÂHe-oam_∞ uffuxmnmde-°Ie™9(`(  U0t((rÂ>
h°$`% *L{`isù.,dY -Er$vhs(¥hÛt ©k±,cpdatdÓfkeemÏNo 1@…R aN&Ö$`≤ 2*"∂∫©))9
(wje.(Ïwe“·nG=pw$fO -l
ö  `!(† $epI.dΩfMÏe$>Ca `HK6s9DihÂÈNfo9>.u<L9|·- Gi)+dAfáöI 0 ,,¿!b5&‚e:-bye-ÎAe;	†$àkgtq%bqc4(m- ($† uc0	)!

(cxdƒ4∑~`!Ês-MˇdÂ-2|!l'Md§fÏaÓ„"fAq"@±(!$p)0  !kbb!<0(A  5 &kEx (»t` (gzs=‰do`-‚Ω~vvv89J† %9(!,(!=§!¢40@(  `Ä ( $"`+|<=#h'Ngu/`ms£ÒCt3}AGq!p≠ztZ≤oÂ°=( "geFeR˚c #vr)aomÂ-¥FˇO:(nqlC1zgn?èexeÛu|Mb!xb>s √¬SDc—cMD±LgS f]S".B]d*IÁ Ùh• a|Nf…“®hNÄ#% q#g8atns "ñÚ'5}`qÙ.
TÎNdÌ√`VUE/$ISd f_n,n!m@XjÙIka4%s†Ùj‡Ù }»u¢co-mbnd go+a`Nt$ÈP°^g% p‹,``{bm¸&~tEw°&hÓE{.@îThyq k—`{ml{@wwÊ,dc_ebEarN%Wæ
ÃOzT_Fdaab‡!f5nudÈlj!oc!,ga`‚fıgÂm|ltkaae∏e‘uäuÒpe$ Âuƒ¯e"Ê-by`Ó~  *cdTu“`qss%ng mg0ap|l`°#bTi);"  ®u-NeK1 p/3tboc°¨sut Ä~1Ù¯rÎc$™'yÁ‡g2d)!N3e(mev°(vef&3p†nÂÔaumt-5izMk4o2y)		4 †3Z0ïetfálja¢pe‰e<SFt.`uFÊuzwK %1†åceˆe≠s◊m%-¬Î&Ê%rrni*(Á!xbd·0
i$yb÷k%id7c‡hY*/X&ir∞Dœg-¸i"+)%0! 5√ø%ss`´d°SÃt0clamc©`(mzJb "fÏ-VØ@viÔıËD s‡ ¢ lir4¢o(S0Tjm[ 9äR¢ ;;(SoGeaW;2 4d5sq/mê&©3TfoÁ'd lijıQaf$Â(p(acI`0/0î/$9ecD
 (*g†En†.` d ÏAcx($m[´ !)U5Ó ,Gd2†f	2h(â `¥ 9!lr®∞„^S5Ï|leilfÁ˝>ty˙/8cdxBk'9ê@IRK“AfFM(	 ±$ ¯3:pd5!L(8kˆa-Ê),Ùi|g/-*Fy2Â` S@r%˝Ë_/∞b@2aÄ` ‡!®Ì1uc˛@(b“C-vi\Â©}Fo-∫tlf=Cizƒˆ){)) &Ë/&!( an|C ¬˝≥0jiÏ/)∞&‡.eu:2$-s`ÏcÏuÂ‰kuhgrAêf.t0h\kS50(ews-j\%bvt%%SkngÏf-lkr!)
b*¨omv\0`3i‚cVq,e{%cqIÂ•QyNFLe-dcR)),4†p |3en9mqmBer£s}t wá)x!Æ{eÎnnvn/sni≠q*Dø+)JIê`azfØ`©'15n$∞pVrisgÛt(xMt`O=,)1gliÔÛi	
!®<cfT]r,}/$e0<Npk 8-ce∑$Ë!qsooJÌl¿®jÙ7)fUvf}r}ame)ÅlicT)(pc)
  ª 9ß÷c	f|dkn}–&cg-gKÙ¡K|fÛ\z•g-oiÈcÛ§2"Lg„Mu4hbaedDnhmg$mÂwscgUs 		â "h®,cqctc>iu|≠,vÊcgra}ic~wLÂƒ0ememAyoÙ=@o%$mÅH"¢0[Âf,("Ókg&dx `÷0m2≠U‰e)
©$!2 di–uÒq†pfstprÎp2Ìmb Ëi1!ˆw≈ÙslqÌy p¶9  (f   Ä (  r!8a   ®lqmb`!·#+B,bpke`|Ó(0R!
®fuoca¨l4cÓˆer,iMe|+y·(´* Ë00¯3hdn Qaqz%œ$ ≠% 0!$Ep5(†mÏ‰(Êhw
 , †:ÂG ~dÌBUr¢g-d!("Û0a¸u˛
"bpdPÙu&( 	>VI’LM:0Ÿup*a(À©âã3dqPsEﬂym·of`vafS`W@≠Êl'%4O5l‡uv
∏MCha ˜ƒcklj Õf!jifg"ä #$ c  `Ä, p a"Oı nab88,@sd†(2ÜR-bÚÂ·tiG¶yDadnB$°˜ÀSFC_Ee 0Ç™;" (b+/))
(h`   # 0— )˙p"pgzw"Joc))
   #(!$ <SfPq(x~üoxvzc le]b$a‡H1ä¢ † ‡"8) !!†(* !	°0 ' ®gP-pI|aÌ`sOkgÎ{†,o}})ca!Hfwif·€qzL}‰#&¯-fi1ë
p≥*vfl à(ê !†,)!p $  (.w^kelÏ P`{9-)°P1$‰(3XUh)c7bM¢ıebxfÍ≈2`≥5‰
 $$$( he0* {ÓhIbit-vd dlonÏ˝fTi',DÙesOmvu.fgj	)Œ4‡)  ¨}E˜q¢oa32R7nnhmcÄ·˛Á$áS¢.|Á*‚m4(D"@! " )svqwml0bœcec{!ezg6 &e3 rmsf¯2Bf:o‚meqp)$`i+äàs\Dafu8Ç#~s}wdA$v+ 2cMdrdhb˜Q9wk< p(	≠ "Ä ` ks] sè_¶f/ntgpafÁ%ÆFi[c†cdsAsos urvwoc	
(237%g≠‚i√NC˝_omkee,‹f-ˇ>Dnt*aD`mlE¸e°5vm¢b√Æ{!√fSAP SlEbG\QgWA/fp|®e8saeubp£D,rIË%•diH4aQ‚È#	vÒYsfd ty¢dC∫3uSzpnib rleiq'!U' no|˘ Â‡2ny Ã
e c}dmÂz> tc
 ¯fiÏe˚§FÔ8 7~	gËd~ mAce≥ Sd.sg':ü(oW KJ@»„i¸er tha4 CÕÖ†sh˙u¨v bß@o/t ÊÉ Ú5Ø#ij tjm(tgN°wDF˜g-ˆ-&ÑÓb' 0fl"@rhuld†cErmo]n toÙku usA3n0 AtbuvÊm: a\*Ämw$e(}k" Ê)uÛ$f H2%†hÂvore)ÆcdN1 B}"ajys/ËtFdl-n&kÂ-ei˚t1.$ND´¡@aŒOÌ=PIÛã0~¨jooÈi ynbiÔiuAS$&haT†t!m`cG|iEvB†wÈll`oOu†Î»anC5 PÃm
¢ aoNe/0r od(nË~e1ú†!dkySi„ ÛFDy iseUab˙ema ÙÀ?serÆb  © "w7(oÎÊ$-ZUjakEf fl9√”&(qˆ◊/e^aUÃmebjat fcJtHr,s-d)ââbu~  +ı2t=mp=*utfesÏHwË5ksb/U0sm‰0,
@ªjÊ>t-'ZMgD=Hiwg`hF|%c`£nf%•Ê·r„
âc˛{ wf£ ktrIÚGc(<t-stP3ßc(0fq|˙?Á)I
)leÔunmy*r=Ìo-C0,nvSm?‰ª3uauu˜`" SIm‘\ê	|glpE)0`*UzœwnÂ∂∞s9`4um0YkÚ !\htm{2«uƒ4ÊO<i7?∫Vi†h∫02wfã!a∂gum`~p¨0zm´qt$g3(i∂˙ ,Âos.§BIhkftgrqbtÃ&•xnÁPDBºcîq!llad{mpugRy!∑quU-t`l}≥-.nG±bc¶Û ch!$|s fleew"´(!!+(sn-lMe%-f&3apgs a6l`+SjÎfÑ:lbN4$saAf√&ãviw!e~9zuxgg"P;(†pb$)
soQ¨QÚ	„ (wLez (ÂAdC2c-iuDc#rd©nÙk,(eÊddud$'R~auuz9 p"	0%( (¶¢ ‡& ∞# •‰†!r  à~µy ((B|g (ew≤r·nw-˜ƒÈri9J   00)#) `  ( 7 † 0"2!1!0(Ni)Bxi (+ å9-hPXruLx gugvÂp†Íu6Z†a( $!5((( ))(J!04®∂"    $Ë     e® <cr3G,ˇleœ2meM≤e'xdJdd4+	(I))π:hiu2Ô4c*0EN1-Ût#txzcTs6b'·√ ut„ms~·e#"*Nâ(‹e†eo-cvs)H•¨·bv{(-/„u-‰‚ac∞Æp[IÕPÃG∏ahF|‡„S
  
Kaml „vstve‡}sIng t(e4Êi-A(uÆ‰e vh}$xœÈb4†%‘(p`È•(‰hll.*€&`h9nTebacµmtÏ#nmsv 2Û÷Ò]sdÌ'8≠·U5R@ ¶#vˇ/suat’SmvÍags@#irÛb2¯)tU[ `naV·"q-)
   √>G≠lÁ`u-wuÓ$£taVewH(rÂ.s(2çv"`wL`gj)™(b~Ú≠nOLwMÈ2{ÂdnIm,bRymtusjØ°;buf¢ c^ˇ-u!%p,"Òg&dz "dFee"%*Èã2lÂËµ/gXÒ|ea%vlpb0VHy:S/!Upr≈7°a#cds-St!vı3=3vtq$ur©I
ä;~ av/ |e

)dTruf¨G6wJMtub9kW~/XkgFmhoG£(°Nﬂ≈”G!!Ë@ÚÎcr-
™  `WÛLaY%tlep"t{ ®k%∞'u ilº∞se¨OcpeD``hlms>JUaV8$t:e`*x%1Û'umgbÙm pnmu±bop%bg; hLaOs<"Çv`ä´_ˆd?dct)vWdË$aW`4)c&”/t‰-br)jÎh≠∞rÁ6i|√â `† ($h5vÛ+Fl!Ês#!e6yh'Á6”-ƒoÛf	F3."#vs!.n«rÆnbeÁ$	/Ω)Ä( :cuw-}fdeÌTo5"mOß" fÓcmsp~iM	33xÁw wm(J
!deDun-Á6c-|kd}88ktS-ˇg4u5pT`tt 
%^çBRbS•(∆|pCQ1!(¬0D¡tw)edx$m`oed(gidDqd
FÔTl`eÙRruÊi¸†BzwQOeN|lrÚomRt,v'6`b\w dÏags.c
 ")Ìf`maA|ym"(!¨‰i[t"®C&bâwed˝bran˚h(0RA~ox
	&†(·6q,A‰eçÎac…:tas+'b3Qnchdpre^K8
?b†π(sV{=#XÚG&?q}ey 7CV2-Q∫ÌG]#ΩNdÁnS$6„tr†up`k¥eÄ'‰qgr`8
&`"->"- Ç-j+)
  (gr≥%moUedº$+ıpÂ„T·* vhEgÛ7p`te©)JJ*("ıw}ji#vR-olmbhbrW‰lodg-%®·Øyz¨†. ÕKAbK‰¬9Ên£fsi` iXe/g¯&}iZ‰2aÓm@ÕÂra‰"(oxdg&Wmvj†e r!b	x$!sGın\jD,	qroI0t rmr4cvsnÃ4«s"
®å)cÁÛa2·'Ùyg'*°! jliw$‡,{61=Hdd-b2efÁhr{ml)pπ"0•c˛s1a‰d5SL„˝f&·r˘=pr·^cyÔppuóox
ã$`§({TS)kl!WÛ-}u(rQ1" wR≠uqd5%-Áƒ£◊s&0b6S 'o‡5pdeÙub/nBfq()/$`†nL=,
,˙b©!
 ,(#VS-mfte-%Œ™2upD£tl¨fla#s"nÏl CfcÒvcs /(“èm++†˜fkFt=mance'pi3C0T)<P *ÕuÊ|j-yvs=ÌDÂiuvr,mfdu,©Gn„re ()_`"Avr`lF "iÓ$4,AVGF~0√f+gVeq6if(ÚedEÛÙµe£7)ÏÛ|UHh≤ ol|Çp )ohoZeq(fÈ %3 tiat0qÚM†no| glag5aa0„ÒhdS#kl˝An73ª BxÎlÛdsi€ti∂n9
;,doÃqu (fi®uv€¨˝dy,-afcU6ê'aWBkseaâ †† 8w+)£6sª!—∞~d/ƒØ-≠wlu]$®e~#mÍil%1l&o<ı)r d@) ¢c*Rlnalazj&oà|‰y*g¶BI	äãO$9)eui`v7MÙ)¯%if$w,>Í5bt9rÂ∆®)"gMUV'dMR)+
   $}'tF%,c>f≠fi<m˘nn?7tAqe0w.*9BHYD¨™Å )Ses-cp≈anmÙ/wO|d}ct-]f #vs(q|]k+e‡ lm-∞EiJ nil)J(‰EbIûimobolu}•mÌY-cdÈgN=ymhas=6cf{attunl?4o%£·nOrÂ†fsçwS3yÂy¯uh/pO	ygnise® †""<¢'Ö´à4u&wn B>s-}/E-fIN`%yºE}}paur9'MnpN} '!
3uElÏDUBqkÁffer†eÔÆ4yKnÎl·°qxe®,`ma"iV a:ÏTÈe2†Wm÷Do?. b°*knum`l‡uyÙe(*LÈsw6~Cs‘$0tT/aˆeta-
:2c29ONºt$nik‰ nal!#g*∞©)
-
òdemın1!~2ÌÕKÊeÍpxx0X)9Ì?©¶%"(e› !¶Wlœ˜`e∞"4dwgr@b|.paiÍHvG"ph!felE†x~$AnızeIdY?foué"J 99Ìt}rc„tu~ç„(<˚kd (a Ù)Ègp|t/-&gnd)F hÁeq§iOruld;>dΩF`vc®e('tov\-Îı$aÛY©i2
ädt‚un0≈bs)ÔodÌ-Es3&i]Â hm)
,0b÷9lı Ùl5 `‡Ωw*Ç
l()NMer·br9pe0j(ht$niru,!˛ÙuDŒ5SCJdh©â`y~s-ode-nmfÂ•6kle‡E0˘h`Ù-i

å)lnFqd Gv7--/‰≈/k·ˇ/fAËgÑjtio9,wI Dk -5!
0Å&◊`gw 4hE°$Imt0)˛efmtx%:`˜ihDo~~2 `(aj|Usceıi6i2hac41Da[7ioP?u'mˆm)Di©í`† ˆR/cfd,Øi,d.ZÈe(%!t$tki"ä $Â2qf k6„-$©jl5iodi& :Byk*"<g4h
u!md'"uNweÛN"! %,7ÔGLxv%w	D) C~{9prk%Ú°W‡nil((cuP>Â.4=Bunde“~ÒF:)Y!∏"Ær2¨"d)bÓ0)£f0mffßk~f/-?z9ga&hml ` !8F/t+ceaz$ poAŒp§}kn)É†$Ü ig ;ra-s`cRa(9`gVve2E∞(Gx|*|U∞<+›w0	OÈn%q-*	(s ˙hNG-t{=Fe%`sK®eqR%jsqsaJgrπ+/+!§† 0p I9
&%vÂfÁtv?-o4u-f{*d(up|t x∂ "Or∂Io
·l(gVhwT ˆe&_/‡ "_el5+¥bË `u&nmr Cf~tcdka~-tlA "kwe*ùÎd»(e®pre§x-rotenS9t(ebR'ter†iÍ`qÊIOt ·Z!˜)>`n&") +i"î‰vACph?%†$iÛt1Ï— pe)nfm4≠ova^4dCøRBQlÙpfefhÏ¨cR„!8*"¢;Z¨If1|cm$dvm.Pa|gdgs"†fm⁄,(£x$e£ thi|!}? aÌ6‰}@it(d} iÄv#l	e no‚AT9Án"
 HKhAJAÏ˘~$"(Ø1$(poh~ı  hrVmÁ|  p.s.%3e‘%mÎiu‡.uveft)Ejo ·9-0,ÚwiŒˆ)=π.Q(q *" ejt 8ÃdES (gE,~a\d<epot$Ûwy™º]xosÍe,G.T≠Cit˘~n#Ä +0§ !("≤† ∞#(° 0·`` r `0 (¿  § Ä !" "! † •Êo~u%l#/fÂa-¨Ç0qÄ8  Ê `02c10∞"††  P,dvr-Ëu-ldv,c:“lki|enq-e)°ç©ö  E√doª "^oÙ #$F\$ƒ na|D&!âi xKZ≠lÔD%!*$( 0mig"d9`éﬂ0tiomA,(“iw8#  †$(IgtuÚdcthze¿J.i·ˆÁ:cgÛΩôrmfl4.wÑ4 eOvs=bqcŒCÈPrefjx/i)
8 z/°Êl$Z (ÍvUc}0cuzr`Ï\?b1Ê&ep)+	( à(je@;C-lgd%¨(ÚcdÂ(?im"lal ;Êno t®	
 s Ç† †*†!eÂ(<bvSÈˆÈneS{vk•>Txzuef©!!TITCHCT9∏i p±)Ïa|1- eab e•Wauƒ\*diz-cdovyè© !8!( 8sU5¿"§Efq|m|`ÚÂ+tk6a:≤ ¢(kTsΩ]8p°no=p5t≠bIeÙ`"cfa;ÊiE±Ông--2‡{vdnAh5!	(( Ä,„o{l®,(·8Ì@ls gt[nt/—gÌ‚caä ‰ ‡(4i?p`9obDbf!V@crld-fmlÂ(nGbgl5r, de&augr*(2e„ugVx9))
®)¶ kt@Eb )&…:%d-ofÏ7~=6a?Bog"`dfu~d%$Nekv…{qY©
		* p‚0"I¢{$(dAbmu,∞oÓM ecTo8y	l!â0Ñ 35\se,#Ewees‡Ò~{%NıV;â  !p (cgtp lEbxtl0¨`Èr%"doZÔÈÈir	)JI!i|e2*(bm`(YD$ztz†(#vÛ$r%‘bH5vD-2mvira[?@i*VKtπ
A ` §£ ¶`&‚?‚kn!)~ns-lebU`G6t%roÏ'©Fc√O>fq|=-Ócme*ny<π(1© "D∞ faz!aÏl2*ckFf,®(EQËkvaQZ%nOjU·rm,egw$('dÈ2pldqm`VtÊur)äH	$ eèdÈg∞	A0 "˘J»vgd˜6'>iÔw=√ı"`ır<otngR/u(*$O˜
)$!  gsripcl%t/Ì#uf.esi=vxÂr,wiL,ow8i
â"‡¨v0()fgi%ˇ £6iÌg=2uff,r /s~m‘dËØUO%‰uF"rp±©©é	Å &! "aF9 ( ∞(]|`.Ä
Q‡ crÇ)fyÓt-Êa(Aejd-JÂmp)gvqm¡p`LxÍc"le%˘∂hπgTfFŸ`iÛ%++*Õ0 ( Dh˜ive)3'bpL@4IEj
-§ !0(wÅdef≠O) êê(   *'w\≈icË`6 +¯kknt5-Èf))	!¡ "( §hfvcÛaﬂE)|i,f$@4dCwa%dy∆m•odx6(Le)))-Bà!c56ç´+,**
ht}fub-Êˆ;-maÂ% +kvY9i'uÆ-uf]o%bV@eQ@≈(®∆,–gsm	0x'UneÓdoamÓaNÁÂA£tn Â$L‡-a3JGÙ∞Áilps,‘Íe`f}(e¢a}vee/WB$`…nñ !cfw¥5xe	t  KXIE≥"`ˇà2RnN" 3;"◊È4;"|r%fi¯
1“g1ME~u, TvOÔ6@&O˛¿bvµ ¿å	WY.z!§(jnt70·g\9‘d ,lcyd(Niˆ-iyx(®„ˆ7%LleGs-qq'rÿ"g{r9øEndˇ-ß'aGs0&tneÏ ∆n©˚{f¿ " ˝f°gu2Vd.5m2refyz%za (canl,ÌntMslc<„f$l!'#.s/+,$eØPmVfsv≠8o	kÂg
  bp!mqı*  ugs#6{9JO-b`mn˛sf1'%hdo("·peSµE* a}'°¶4h2%aknEl∞`h$"-rdaF(Fh)âò±) 6R `gs:fq ¨Û~S$fËLfyŒ~m,t{`uPbhcRe	TCÇ+ä		¥Äà·nd ∏uq$kkRc?eyl$ônbO.t[pÂ(&{©('√ﬂ@UI√Z!
)!H$s hkBXˆILi&fÔ¨8“}"|irÂf)h &VMOFaL	)/)ã∏  (g«q-{0l/p®2)fz-P1taÙign$ˆ%oouAfÚ rk)A
∞$ yfM%VGNO4AHËbi~('Îp%stlht… I&!(Ëdiv-nt)E7yàbÂp£wiu-Ûpnh¸)A)K †2e( ∏efêºnsÓlxfix/t '39*©0v|eN(fisÚemgved‡*c4sm}k`e;Úun"rdÍ niÏ8bcÏr•m~tUE)9ä™cvÛ•}'‡mmzuF`"58‡ev· vdaosff˘sØot`gp
), !" `{oS|YsÔoNè`h%‡& ,˜neÍ@&]S-z%m^ˆe,  $0(à0 "p† 8`b ¿º$Ädd(hlÒedÎhref§(buPV% ~%bfB$mˆ!J  !∞ †	 
!$ 0@     0∞Ça#(l!EbL… hx'*b° )!0†   !  ¿ $ ††! "§8’ipi-'ÏrSeJf}$nur»&vB
   (  ! !a2(∞" É! ±  (0B  )p7xsts-mØUe-pÙn #adj" iiÃ$j$S)w@ddÁ!©	i©Å)ô)(à)0mefuÔ-cfs-ÃO`E! „ÚØ.g‰e)P·6uSÙ/‰˛≠rev(>"OO!O”*0ËÚeR9$*R%fır‰ qhf.caceOuDa ÊiMıW!tÃ "N olz2rtÌ1Yøo."
 p®[>Ùe2aCtqw- &≤®j){< @op∞(Âˆs=r∆Öfh¯-oer!#„b”="ˆacH-p2L‰˜8©J$$ $$\Meu  &sur{·zÙ=qxÂdYπc˙o g($) i
ädÄ h†$"c~36l!g3-1uDÚy"eBv3!Ihdf-fArsiÔ,%+)i- h latj (,Vm3 )cTsndu)eAvÍdD0WWA~Esp¿"zwVuvu $*'i7E dk!
	†0} /0	CmnAÂt ¥m8[@cx=r·c
Ñ4-)kM!tEe–-≠¨p¢*/;)" †-1)0*Ñ($dpsurreˆlM:U‰ber…
	0(und!s#hLA|Bda!*≠
 !!`  •ÇÈ8  0`d!#h(Wyt(m#rrUOt$te¶nu`®bu‚∫H40! 8+tw-e?4e	ˆT
 ÙCg¶!`loÚr‡%>¢ ≤ccafi{)=)) I(’4dwÙÂb®laœ di§89®c  k()y†! †(  ‰ #;u~»!|2vEn|≠BUgÜEp!BeK p∂±jKr”)eode-rïj "uPt·een!(mI{4eÚ,ÎjÇq`m vml#®r≠v'	ba±	k5¡†$`o{T(c"ntawà≠!;(H H$Qncw{8icde(ÒuDØvÛc`%0ËasV&\h`! fkÛ):pÁˆtprk@Aepd·p·+)†N‡d%feE-s7:çmo‰Esus,<$Â-‰Ôlutk/|/wK")J°¢eeX5ÙetË%0hÔk[(∂imÈ xHBr6WS¢q alumœg9f>r.
otÂ§x»%t WjW√sËn"se dbnMUÒ u;.$o·bE»/ıHoÓL`Be<|xÈf#[n%y~Pò!re!bO/P…nsu$%|Z·u wha`‡fkcewÄTliÙ‡Í:$aıÂ»!|h` Ó¡oB?s |eal.àJ®0(in<dacti?q!Æ
4Ïm%*@i´d fav@=tkze„¥r{`(g6pe^pa,uçd)3	m%m$Rv!%Ï/cÎ°&—di)
-(ln„ks (DÈS`Cwcpy-§(=Â tÂvs1lv≠‰ÈzeD|ry"hif§!fÒ≠jNsk&&mHgmI}îep˘©lπ!"  &one,)0 ("/o|(x}cYs≠‡uppÓ2 6fy<ça‚S$&mË%["
oıdd:)-h ∂@¨  aıor©n/-q28„kéyÅµa6BE`Ï,Y†Ê'l5¨D§MoccQaqf ¢
csÕ>Øs{-Íol∞"≥ÖJ))	d$$ £$àeoÈ-sp†,,G√k†l?j[s	iz/Lje(,nÈae-EyfeÌ2orilX(lÔbh+ *dtlVt%d´pmCtpy ÏOCÎ©	Xb` !$ niHe,| {pÛ7T lgo)¢0t5o}‘E-Fi¨E`^Ôc+)/+9N+)=

¥ $efWv-3~Û+¨% Cv}/m/de≠Ú≈EmUu-jnd~a4$	-ô`ä"rÌ}Of%∏hl¸`li~	r!:jA|#a |&*aÏd~mD™*Õ˝ttÿ)`isecP7qiespQ2aelsr•l>2" 0(i~Rdr‡a|A4i)T0	g<—I.ıA.wqecyÌl‰Ô|pKF¶#fÛ$bofmieb 4'3ÏLb®Ns@V3)aw&ß+ze-oVeΩm}ÚmkxMÚ)%s1hANtne` t©)
*(fm64NJi^QÂ~Ùa cvq-mofe? o„nku|%fgi`l9;  b“dÌmıf Èhl iaÚk%Ù"f}jgspbiÃÄtHÙ"ru&foR$"K" hËÓv`rqgXHv-)†"8dohmÒu Ifa1iav{≠o%T≠eÔ“kd"®wrs•Èg~Îgf=d#rÎs©Q *%#"mwdeL'f#l$u+° "!()c6tˆ(hqw˚-bi|eiFfØΩnt˘]‰ Pxâ83T√D)	
$"™avÛ-s\Fa%5p,jwmlctyŒaAˆs≠gwM+I‰Û"Œi,)LLli‰i+J®tFbtZ!bds≠pjo‚≈ooZqDÄÊkÏtEv d/`UKooDE)wÌÖÇill)ä@`*÷emÔˆe+d»le{
) eEuvls!¡Ä/icÙ¨of“Yó$thcr(sJbX<@ g54p{ﬂc†5amgedl"
00 Ï-|*dy8bmmuc`(!~g=ode/mycog|†∂i,\V‘sttÄ:c!xe%T.*hd±&$_.¸ÒbÙ)(
"∏kis ´j=2"9„cEparta4jog† luapda"8˛ÈI 	‡~  |U1:itS=vo,eJ&dÕ?txpu(˜i! ]~âoﬂW¬*9I)`*Î)TC•}od°Ô}2ntdfIdÙ%r0C=l´`	J	†#i8dÊt xn˛†(xoÿ¿vÛ-W5h6oÚi=r%inv1\s+J)ã4" ‡)cV≥-^ebyh(dq/bÄe(jt™
	ô	Ñ (os!djou†"Fi,Ò-u\ist{’|
!)	 (h:b$^s)gÈlejnfo=:f(|fmmu0f`()öI@&(  `0 Ctw·™qLLba¬hd	r gi ásev«/rm)l9 _)f{`ey!+	∞πlitc≠G :„v{%pe})"YbF˜p)a9ä  c Ëw©`x·n$ hOu"v˝mwnF)b%qEw/(kˆÈ%C'‰Ïup-ÏÚll^6elc"mhst)-$!$  ‡(wiÏ)«Èzrƒ~p-Cg&Cfa tmpR5bIher0†88irhycit;wAf%ldy`9âI™ aˆS%yosdtˆ%Ú‰z9^v≥3*,e`cir83cTsMF)<msÏfmm7g]llejC~e†nysy!
	¿!<Éw{)RÔpmq}fıFe2,SaeÂ-r·i'†8C6v:ENT©bÙfndp))
f!8s®ÚyJu/∑ineÔ2-+f-e¬rÁg≤)tËan-`uvNM"+	m;
(0≤(¯ˆ n¸ku(ymx`qimcnd™	*anbn$-uÚj‰mgtnâH! ,d4x=dw≠gr	fO7—
		" 0 (©©lud®1~f)≠a„"*$ej˜`p <iv-q-!nÖ   !(Vc5b∞"+| ®gu!ˆ)d\‰z†w]Ó@o$r≈N`‰$(aletÁ")©)	r)f ®)(5nGxh¬rà©p ` ·Vg“-eR"ì f°lfj$‹2s~& ~ b
-ô∂c!GtARÍIç($¶  Rˆcmgylm!o§o-:gÈlu§kpv$dgm‰s)*(	I	$ (&?ÚMct2¢$sdÙ Omhfs9#2	L	$}.mpbã]â,	  >fcÌes®)+)∫( 18cVs¶2tVy/)Q~ver!tpbuf°v1P—frer-) 	)TjsgO† hEsÒÛÂ "¡Doí|inf¢)(niL´
1t   j$om≥r`®ru fi<‰Ûiä deth`8†pYqg "cvq¢fiLvy≈6è-~|xr· "y	-jâ$∞Ñ1,8xG	.d( czg≠2mÓ•	ºeo,~&5dX/Óa)u 2h#)âµ¥‡ 7huj((oÚ Á, "˜· tΩ`$`$1Î~ÔWL©(
"#`!Ò¸eÜ Ëfma)Yy~t3#p0gi…i 0jdeluVı+Ñale%emh% ,
â )±$mU.de3ø*aL,(lsı&`*br1*ÁÕleilfo=>{Tigh! &LE@D)Ë42=2/J!"b  #yq+h)J
)d«reJ-+wryMgde8g~q`ukde	re}cv`p"Rt¿L«	 ºGlßs!("PimcrE
allpIibke‡`ÁEiewÆeitl(YbdÁh|0rg)hNgm pbÈ%P6&Ás0É63 ¶l!ÁcN"  ,yotEac·tivg(DËm—¯ i¬∂s-f.!Bs5pvez!'SUw-smÌovw%gl!Ss"eVi reooJU1LaÊ©BÇ!`lgÙ à†.yS
¨qt≤ifo≠0|-owa4grmwÎÊe))-  !†8fv†dis#$@sÛ/lèDeØR˘kgrCgÕs5"@,Cojø Blf"`ÓhaF2! C`#)õ`b!  0%gtq-b-ÂaÓYx≠qoh¨ebvi/n¢cˆy≠cfooi%sHnaF¨kI,2,)l©()©æ
H∏d%fviz@cvs(tc‚NA!$
c)
(pÂful%cVs-}Àh%1xsuq≠mO@mE∂¡g ~"√YMRÕE)2®4@f0&?uÈLnhd&Ê$qg3)""*V,n&‡fRy |b&≥Ã–%'9o‚#im¸°ÎgL±Ò<eÏ-Êqxu√zWÕ4`!÷ee`Îz iz'WÃeft, ‡romÀh86'“8Jıs†f, aS¢Æ ˚$dVF!TÃl Ùhjc$„q,(n.lx hm¨¥Û˝`oH0DIsebf)Mef
UYÂ qL
ogw≠mod%Ïnr„%-k/-o#Î !gj cIeo‰i0‰√vs-Êépo]®t¡v)da#&0"yBuälMuv <·(esm1kT$on†yxn9vid∑a|pFi‰5w"
`
8i,<ifiSvk~d™   ¿I[7"ƒsl1Q gV[-fiıu.AmÂ™i± 0b‡p(ivrÔpuex}¨RE`! cra/ti/©dqΩy1#tc˜0naÌL2(&Pdw=mupodewa+>ÒG()1±(#vr-ÛlCg7-9i]tnub_aF=oduuÛ0 Ù#Eµwla'3 !ä  Cfr/%«f≠=‰O0*tyã y¯`ˆ8m&H:∆|`ßsixm)gÙ0Tq'≠( # h ¢4.ó(Âf fu-njce%tiP-Ùfg;|„d	/©
é(dtfvk)#vp/Õold +m/3!X˛d•-}nxa8&"ÀÈMEi".qag $oˆhoNpx >|agpΩ+jWTlb@c6p(Tew /f TI∆6Ä/ A|d 7E$%CÙvd4tad`sg.givh p2E~xs<ıc}m•Ot†pzgMptDjÔj!cêq`&,¡icn"™&¢ k.dÂraaTdve
µÖ(9hYstH:3ua1 cfÈ-aA≠VP}E"!‚  †"Ñ-crs)hug4y-2eed0kRÂ-ﬁ·Ûlœai! bV¡_3vm!tU,eTGj!3J† 000) `02 e$!((""    $b®"c†C>|%qpkcd•srydÁe)≠%°mvg-glEgs|q;eÚ; 'gDP4Âw%f¥cgc`*DdÊ r¨hoqâ))2b,ARp,mDg-‰O 2tag´0(C2xMEL‡&†&m `  nmaga`¨lise0Ùag))p$ d¡ †(¥hmh c69mvgRgkd{ÒmtcC ˆ‚ae∏o9
+õ B{vg`‚{O@zlebi,eCÆ
 daFıf,6y-ge†cvS%m?Eebyl|=iÓØt)Ïl-oH.5≥!(K" $"¬5n`0y\e/3oluk‰cnhdE"?j∞Ilu ˚exesud(¶Ètm˙’qpxê:tàg `denÛ´nÓní h)nT‰saaire£h§™|Âpp((E‡r)Âed6wŸoeÙ-xq`ku$ (vV-kvln>Â©oGV9_x !Íy\a-b/mXKl$'!kz±Ø†h! i¶O/IÛp!¨¶h)-∆rkL@,J  $$ $(›≈&(9ÆÓkdeÍq…e )c0q=NlDuin~w%>n˝-ÈJau!Th(+88˜hml"ys∞iÔg)M)v+Kp"\T>e~UN%.†ÊilMF≈^Â;0ajite+sfeÒid≠˜Ò,Ê bi[‰˛hme(©"àk+ä;+ sheno$/of¢qwp`es|.¸(‰eÊTij$a‰(m,{-wnfer#'IYg-Œg¨%-fvdÁ4hm
ã(ÙEF5n-cWSmlnÓ1vqm≠¨ß5ifm=1`]nÁ%)LKc-Ô.‘d»ΩØ:hi>(ÁJltÒ†x b‰d\Â`=d·jgu\Îf$%v0q(oz"hiCo.gDMjg of(&hƒ2"urc,eT‡iŸm'tsq/b$&HinÒe@Ag|)|ç)ä(y? StqeCVW0iaf)loo a8Ò,maiyh94∏bdEa/se4k$&	|b$eTrv≠5ˆoLnae«p!SHio sE(#CÃm*%br;,·.D=c:ijhe~>gd£pryùGtzÂrmw]ndI†b$E˚y, $H} h˚;hCdd=Ïe-*]vgE„fyl-nAoe-function ends up unbound when we leave the `let'.
  (require 'add-log)
  (dolist (fi (cvs-mode-marked nil nil))
    (let* ((default-directory (cvs-expand-dir-name (cvs-fileinfo->dir fi)))
	   (add-log-buffer-file-name-function
            (lambda ()
              (let ((file (expand-file-name (cvs-fileinfo->file fi))))
                (if (file-directory-p file)
                    ;; Be careful to use a directory name, otherwise add-log
                    ;; starts looking for a ChangeLog file in the
                    ;; parent dir.
                    (file-name-as-directory file)
                  file)))))
      (kill-local-variable 'change-log-default-name)
      (save-excursion (add-change-log-entry-other-window)))))

;; interactive commands to set optional flags

(defun cvs-mode-set-flags (flag)
  "Ask for new setting of cvs-FLAG-flags."
  (interactive
   (list (completing-read
	  "Which flag: "
	  '("cvs" "diff" "update" "status" "log" "tag" ;"rtag"
	    "commit" "remove" "undo" "checkout")
	  nil t)))
  (let* ((sym (intern (concat "cvs-" flag "-flags"))))
    (let ((current-prefix-arg '(16)))
      (cvs-flags-query sym (concat flag " flags")))))


;;;;
;;;; Utilities for the *cvs* buffer
;;;;

(defun cvs-dir-member-p (fileinfo dir)
  "Return true if FILEINFO represents a file in directory DIR."
  (and (not (eq (cvs-fileinfo->type fileinfo) 'DIRCHANGE))
       (string-prefix-p dir (cvs-fileinfo->dir fileinfo))))

(defun cvs-execute-single-file (fi extractor program constant-args)
  "Internal function for `cvs-execute-single-file-list'."
  (let* ((arg-list (funcall extractor fi))
	 (inhibit-read-only t))

    ;; Execute the command unless extractor returned t.
    (when (listp arg-list)
      (let* ((args (append constant-args arg-list)))

	(insert (format "=== %s %s\n\n"
			program (split-string-and-unquote args)))

	;; FIXME: return the exit status?
	(apply 'process-file program nil t t args)
	(goto-char (point-max))))))

;; FIXME: make this run in the background ala cvs-run-process...
(defun cvs-execute-single-file-list (fis extractor program constant-args)
  "Run PROGRAM on all elements on FIS.
CONSTANT-ARGS is a list of strings to pass as arguments to PROGRAM.
The arguments given to the program will be CONSTANT-ARGS followed by
the list that EXTRACTOR returns.

EXTRACTOR will be called once for each file on FIS.  It is given
one argument, the cvs-fileinfo.  It can return t, which means ignore
this file, or a list of arguments to send to the program."
  (dolist (fi fis)
    (cvs-execute-single-file fi extractor program constant-args)))


(defun cvs-revert-if-needed (fis)
  (dolist (fileinfo fis)
    (let* ((file (cvs-fileinfo->full-name fileinfo))
	   (buffer (find-buffer-visiting file)))
      ;; For a revert to happen the user must be editing the file...
      (unless (or (null buffer)
		  (memq (cvs-fileinfo->type fileinfo) '(MESSAGE UNKNOWN))
		  ;; FIXME: check whether revert is really needed.
		  ;; `(verify-visited-file-modtime buffer)' doesn't cut it
		  ;; because it only looks at the time stamp (it ignores
		  ;; read-write changes) which is not changed by `commit'.
		  (buffer-modified-p buffer))
	(with-current-buffer buffer
	  (ignore-errors
	    (revert-buffer 'ignore-auto 'dont-ask 'preserve-modes)
	    ;; `preserve-modes' avoids changing the (minor) modes.  But we
	    ;; do want to reset the mode for VC, so we do it explicitly.
	    (vc-find-file-hook)
	    (when (eq (cvs-fileinfo->type fileinfo) 'CONFLICT)
	      (smerge-start-session))))))))


(defun cvs-change-cvsroot (newroot)
  "Change the CVSROOT."
  (interactive "DNew repository: ")
  (if (or (file-directory-p (expand-file-name "CVSROOT" newroot))
	  (y-or-n-p (concat "Warning: no CVSROOT found inside repository."
			    " Change cvs-cvsroot anyhow? ")))
      (setq cvs-cvsroot newroot)))

;;;;
;;;; useful global settings
;;;;

;;
;; Hook to allow calling PCL-CVS by visiting the /CVS subdirectory
;;

;;;###autoload
(defcustom cvs-dired-action 'cvs-quickdir
  "The action to be performed when opening a CVS directory.
Sensible values are `cvs-examine', `cvs-status' and `cvs-quickdir'."
  :group 'pcl-cvs
  :type '(choice (const cvs-examine) (const cvs-status) (const cvs-quickdir)))

;;;###autoload
(defcustom cvs-dired-use-hook '(4)
  "Whether or not opening a CVS directory should run PCL-CVS.
A value of nil means never do it.
`always' means to always do it unless a prefix argument is given to the
  command that prompted the opening of the directory.
Anything else means to do it only if the prefix arg is equal to this value."
  :group 'pcl-cvs
  :type '(choice (const :tag "Never" nil)
		 (const :tag "Always" always)
		 (const :tag "Prefix" (4))))

;;;###autoload
(progn (defun cvs-dired-noselect (dir)
  "Run `cvs-examine' if DIR is a CVS administrative directory.
The exact behavior is determined also by `cvs-dired-use-hook'."
  (when (stringp dir)
    (setq dir (directory-file-name dir))
    (when (and (string= "CVS" (file-name-nondirectory dir))
	       (file-readable-p (expand-file-name "Entries" dir))
	       cvs-dired-use-hook
	       (if (eq cvs-dired-use-hook 'always)
		   (not current-prefix-arg)
		 (equal current-prefix-arg cvs-dired-use-hook)))
      (save-excursion
	(funcall cvs-dired-action (file-name-directory dir) t t))))))

;;
;; hook into VC
;;

(add-hook 'vc-post-command-functions 'cvs-vc-command-advice)

(defun cvs-vc-command-advice (command files flags)
  (when (and (equal command "cvs")
	     (progn
	       (while (and (stringp (car flags))
			   (string-match "\\`-" (car flags)))
		 (pop flags))
	       ;; don't parse output we don't understand.
	       (member (car flags) cvs-parse-known-commands))
	     ;; Don't parse "update -p" output.
	     (not (and (member (car flags) '("update" "checkout"))
		       (let ((found-p nil))
			 (dolist (flag flags found-p)
			   (if (equal flag "-p") (setq found-p t)))))))
    (save-current-buffer
      (let ((buffer (current-buffer))
	    (dir default-directory)
	    (cvs-from-vc t))
	(dolist (cvs-buf (buffer-list))
	  (set-buffer cvs-buf)
	  ;; look for a corresponding pcl-cvs buffer
	  (when (and (eq major-mode 'cvs-mode)
		     (string-prefix-p default-directory dir))
	    (let ((subdir (substring dir (length default-directory))))
	      (set-buffer buffer)
	      (set (make-local-variable 'cvs-buffer) cvs-buf)
	      ;; `cvs -q add file' produces no useful output :-(
	      (when (and (equal (car flags) "add")
			 (goto-char (point-min))
			 (looking-at ".*to add this file permanently\n\\'"))
                (dolist (file (if (listp files) files (list files)))
                  (insert "cvs add: scheduling file `"
                          (file-name-nondirectory file)
                          "' for addition\n")))
	      ;; VC never (?) does `cvs -n update' so dcd=nil
	      ;; should probably always be the right choice.
	      (cvs-parse-process nil subdir))))))))

;;
;; Hook into write-buffer
;;

(defun cvs-mark-buffer-changed ()
  (let* ((file (expand-file-name buffer-file-name))
	 (version (and (fboundp 'vc-backend)
		       (eq (vc-backend file) 'CVS)
		       (vc-working-revision file))))
    (when version
      (save-excursion
	(dolist (cvs-buf (buffer-list))
	  (set-buffer cvs-buf)
	  ;; look for a corresponding pcl-cvs buffer
	  (when (and (eq major-mode 'cvs-mode)
		     (string-prefix-p default-directory file))
	    (let* ((file (substring file (length default-directory)))
		   (fi (cvs-create-fileinfo
			(if (string= "0" version)
			    'ADDED 'MODIFIED)
			(or (file-name-directory file) "")
			(file-name-nondirectory file)
			"cvs-mark-buffer-changed")))
	      (cvs-addto-collection cvs-cookies fi))))))))

(add-hook 'after-save-hook 'cvs-mark-buffer-changed)

(defun cvs-insert-visited-file ()
  (let* ((file (expand-file-name buffer-file-name))
	 (version (and (fboundp 'vc-backend)
		       (eq (vc-backend file) 'CVS)
		       (vc-working-revision file))))
    (when version
      (save-current-buffer
	(dolist (cvs-buf (buffer-list))
	  (set-buffer cvs-buf)
	  ;; look for a corresponding pcl-cvs buffer
	  (when (and (eq major-mode 'cvs-mode)
		     (string-prefix-p default-directory file))
            (cvs-insert-file file)))))))

(add-hook 'find-file-hook 'cvs-insert-visited-file 'append)

(provide 'pcvs)

;;; pcvs.el ends here
