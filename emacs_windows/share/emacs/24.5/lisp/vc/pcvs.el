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
	   row3!(�� �)@�|)�>( cvc=Yjdk/Yi@gi�"�fmfd Fod��fb:+jg v {tind(�h)
$(3&(dut� 8hҩH$f(jv{/jil1ykB%
Vq�fM�a%e��i�)�(�*r%�0-�4n )G2?rv�kE4�r�Yyi"d�c0(/r*3�f1�cCKS�  ;)� v!e2/�u& (Mf!B V0`aV�=�!<"�fz�%rfv�r	oj1t�0r`�r))!GL� �;� uhI ji�`ihb+�S!e2�A �� 1�s9euid%qqid��Jnzk"ial ��da-|rL�shDjd<ytfz�r2,L)rtire��4b�� re�-ru$�� � 01 hft.@-~hh)cc�!Gtc,ad{f�m)la�gk-�a.L|ap3�	 !80�Dv�21(�`b �cs�r�T-"uf�vdg -byh�mko#�huc6!��d��1+i)�(�!`Un�cw}��e* Lrs-�&F$�AL-ff�oT<o�,.��GS �
" FagF�)nu'pcC�i~mMq"�@rzdjT�F*e�"�o`C�v�wib;��ECxA`|%Bpc�y�a)
  (>eu*)(:peo1 )b-pz%bMx&%DT %cv�ra`�(-}rg@y`+9�(,fast Qn& �Ef�$(�vmqpmkkx,�Mta�S-V�e�nT"sx�za�np-pr���x)))!�dhs�,s���l|g&mQa�p�|afn1"ie)o�"$�cH�E!t�qb "(0X�je��/!8m-ng\x`�is&-�#�$@�� 4zzk�a �e��/odHcr�ci>|w�bM8!pplms`tL��o�u P|A2gmles i$ �v�iie�,)� �8(la5n,( �i� i�csfia	�	 p0s>qobtv0)&"t 6! *cf�-bEe:i%k%re6a{#{~hfM1�rgR19
 (  � "$GK~l-z�de-n~uDx$up )Afc-nml�y~fg}
qll�Oa[� ni5+9I)r	�fe2/buga� �# 0�ip0jtw�o}{8.K b- t1k nm�`.X�q`FYr)=iJ"  *sE|q*`gv�-�TfI	���if 2ev6b0cvq-ree�ieVEmsev){y}z!w�3p%t+*A	*  8$InLRm�e)ose��ct`hrRs�wym�inb/->gq,,n2m3 FI�))�		:'t�cx siGy�f,�taeP�dfusN/� kn/u@uj�t otH)� do+bT�v�v`d� }saf);K  d�8�na|*$):?$e�p�(�if`m~E%	�(�ad�r(#�w��id�-st9vp-hn{�	   0 Hgvs-U�ansma*�'c\&fqcs 4�irT�t1-bw� vg�'rqf(A0*	�b�ob�8�-!p Cvr �hfgioe2N"en�~�nerp+i$Reb15k�fVq&�Vq�A!)+)
�"d�ftX�efq-X�=?m1hi}(j(fy� 5<2!�����^ni�!k� f%f�e#&K#`�ns�fEdw�e	v@	C �INdj�)�! !w(}�iqtS�nf]�bur"gwM�,ne,Dr-a)
 ( �3e�u�b}wfu�-kilm&namEtfyxynd�s�He-oam_� uffuxmnmde-�Ie�9(`(  U0t((r�>
h�$`% *L{`is�.,dY -Er$vhs(�h�t �k�,cpdatd�fkeem�No 1@�R�aN&�$`� 2*"���))9
(wje.(�we��nG=pw$fO -l
�  `!(� $epI.d�fM�e$>Ca `HK6s9Dih��Nfo9>.u<L9|�- Gi)+dAf��I 0 ,,�!b5&�e:-bye-�Ae;	�$�kgtq%bqc4(m- ($� uc0	)!

(cxd�4�~`!�s-M�d�-2|!l'Md�f�a��"fAq"@�(!$p)0  !kbb!<0(A  5 &kEx (�t` (gzs=�do`-�~vvv89J� %9(!,(!=�!�40@(  `� ( $"`+|<=#h'Ngu/`ms��Ct3}AGq!p�ztZ�o�=( "geFeR�c #vr)aom�-�F�O:(nqlC1zgn?�exe�u|Mb!xb>s ��SDc�cMD�LgS f]S".B]d*I� �h� a|Nf�ҨhN�#% q#g8atns "��'5}`q�.
T�Nd��`VUE/$ISd f_n,n!m@Xj�Ika4%s��j�� }�u�co-mbnd go+a`Nt$�P�^g% p�,``{bm�&~tEw�&h�E{.@�Thyq k�`{ml{@ww�,dc_ebEarN%W�
�OzT_Fdaab�!f5nud�lj!oc!,ga`�f�g�m|ltkaae�e�u�u�pe$ �u��e"�-by`�~  *cdTu�`qss%ng mg0ap|l`�#bTi);"  �u-NeK1 p/3t�boc��sutʀ~1��r�c$�'y��g2d)!N3e(mev�(vef&3p�n��aumt-5izMk4o2y)		4 �3Z0�etf�lja�pe�e<SFt.`uF�uzwK %1��ce�e�s�m%-��&�%rrni*(�!xbd�0
i$yb�k%id7c�hY*/X&ir�D�g-�i"+)%0! 5ÿ%ss`�d�S�t0clamc�`(mzJb "f�-V�@vi���D s� � lir4�o(S0Tjm[ 9�R� ;;(SoGeaW;2 4d5sq/m�&�3Tfo�'d lij�Qaf$�(p(acI`0/0�/$9ecD
 (*g�En�.`�d �Acx($m[� !)U5� ,Gd2�f	2h(� `� 9!lr���^S5�|leilf��>ty�/8cdxBk'9�@IRK�AfFM(	 �$ �3:pd5!L(8k�a-�),�i|g/-*Fy2�` S@r%��_/�b@2a�` �!��1uc�@(b�C-vi\�}Fo-�tlf=Ciz��){)) &�/&!( an|C ���0ji�/)�&�.eu:2$-s`�c�u��kuhgrA�f.t0h\kS50(ews-j\%bvt%%Skng�f-lkr!)
b*�omv\0`3i�cVq,e{%cqI�QyNFLe-dcR)),4�p |3en9mqmBer�s}t w�)x!�{e�nnvn/sni�q*D�+)JI�`azf�`�'15n$�pVrisg�t(xMt`O=,)1gli��i	
!�<cfT]r,}/$e0<Npk 8-ce�$�!qsooJ�l��j�7)fUvf}r}ame)�licT)(pc)
  � 9��c	f|dkn}�&cg-gK��K|f�\z�g-oi�c�2"Lg�Mu4hbaedDnhmg$m�wscgUs�		� "h�,cq�ctc>iu|�,v�cgra}ic~wL��0ememAyo�=@o%$m�H"�0[�f,("�kg&dx `�0m2�U�e)
�$!2 di�u�q�pfstpr�p�2�mb �i1!�w��slq�y p�9  (f   � (  r!8a   �lqmb`!�#+B,bpke`|�(0R!
�fuoca�l4c��er,iMe|+y�(�* �00�3hdn Qaqz%�$ �% 0!$Ep5(�m��(�hw
 , �:��G ~d�BUr�g-d!("�0a�u�
"bpdP�u&( 	>VI�LM:0�up*a(˩��3dqPsE�ym�of`vafS`W@��l'%4O5l�uv
�MCha ��cklj �f!jifg"� #$ c  `�, p a"O� nab88,@sd�(2�R-b���tiG�yDadnB$���SFC_Ee 0��;" (b+/))
(h`   # 0� )�p"pgzw"Joc))
   #(!$ <SfPq(x~�oxvzc le]b$a�H1�� � �"8) !!�(* !	�0 ' �gP-pI�|a�`sOkg�{�,o}})ca!Hfwif��qzL}�#&�-fi1�
p�*vfl �(� !�,�)!p $  (.w^kel� P`{9-)�P1$�(3XUh)c7bM��ebxf��2`�5�
 $$$( he0* {�hIbit-vd dlon��fTi',D�esOmvu.fgj	)�4�)  �}E�q�oa32R7nnhmc����$�S�.|�*�m4(D"@! " )svqwml0b�cec{!ezg6 &e3 rmsf�2Bf:o�meqp)$`i+��s\Dafu8�#~s}wdA$v+ 2cMdrdhb�Q9wk< p(	� "� ` ks] s�_�f/ntgpaf�%�Fi[c�cdsAsos urv�woc	
(237%g��i�NC�_omkee,�f-�>Dnt*aD`mlE�e�5vm�bî{!�fSAP SlEbG\QgWA/fp|�e8saeubp�D,rI�%�diH4aQ��#	v�Ysfd ty�dC�3uSzpnib rleiq'!U' no|� ��2ny �
e c}dm�z> tc
 �fi�e��F�8 7~	g�d~ mAce� Sd.sg':�(oW KJ@��i�er tha4 Cͅ�sh�u�v b�@o/t � �5�#ij tjm(tgN�wDF�g-�-&��b'� 0fl"@rhuld�cErmo]n to�ku usA3n0 Atbuv�m: a\*�mw$e(}k"��)u�$f H2%�h�vore)�cdN1 B}"ajys/�tFdl-n&k�-e�i�t1.$ND��@a�O�=PI�0~�joo�i ynbi�iuAS$&haT�t!m`cG|iEvB�w�ll`oOu���anC5 P�m
� aoN�e/0r od(n�~e1��!dkySi� �FDy iseUab�ema ��?ser�b� � "w7(o��$-ZUjakEf fl9��&(q��/e^aU�mebjat fcJtHr,s-d)��bu~  +�2t=mp=*utfes�Hw�5ksb/U0sm�0,
@�j�>t-'ZMgD=Hiwg`hF|%c`�nf%���r�
�c�{ wf� ktrI�Gc(<t-stP3�c(0fq|��?�)I
)le�unmy*r=�o-C0,nvSm?��3uauu�`" SIm�\�	|glpE)0`*Uz�wn��s9`4um0Yk� !\htm{2�u�4�O<i7?�Vi�h�02wf�!a�gum`~p�0zm�qt$g3(i�� ,�os.�BIhkftgrqbt�&�xn�PDB�c�q!llad{mpugRy!�quU-t`l}�-.nG�bc�� ch!$|s fleew"�(!!+(sn-lMe%-f&3apgs a6l`+Sj�f�:lbN4$saAf�&�viw!e~9zuxgg"P;(�pb$)
soQ�Q�	� (wLez (�AdC2c-iuDc#rd�n�k,(e�ddud$'R~auuz9 p"	0%( (�� �& �# ��!r  �~�y ((B|g (ew�r�nw-���ri9J   00)#) `  ( 7 � 0"2!1!0(Ni)Bxi (+ �9-hPXruLx gugv�p��u6Z�a( $!5((( ))(J!04��"    $�     e� <cr3G,�le�2meM�e'xdJdd4+	(I))�:hiu2�4c*0EN1-�t#txzcTs6b'�� ut�ms~�e#"*N�(�e�eo-cvs)H���bv{(-/�u-��ac��p[I�P�G�ahF|��S
  
Kaml �vstve�}sIng t(e4�i-A(u��e vh}$x��b4�%�(p`�(�hll.*�&`h9nTebac�mt�#nmsv 2���]sd�'8��U5R@ �#v�/suat�Smv�ags@#ir�b2�)tU[ `naV�"q-)
   �>G�l�`u-wu�$�taVewH(r�.s(2�v"`wL`gj)�(b~�nOLwM�2{�dnIm,bRymtusj��;buf� c^�-u!%p,"�g&dz "dFee"%*�2l��/gX�|ea%vlpb0VHy:S/!Upr�7�a#cds-St!v�3=3vtq$ur�I
�;~ av/ |e

)dTruf�G6wJMtub9kW~/XkgFmhoG�(�N���G�!!�@��cr-
�  `W�LaY%tlep"t{ �k%�'u il��se�OcpeD``hlms>JUaV8$t:e`*x%1�'umgb�m pnm�u�bop%bg; hLaOs<"�v`��_�d?dct)vWd�$aW`4)c&�/t�-br)j�h��r�6i|É `� ($h5v�+Fl!�s#!e6yh'�6�-�o�f	F3."#vs!.n�r�nbe�$	/�)�( :cuw-}fde�To5"mO�" f�cmsp~iM	33x�w wm(J
!deDun-�6c-|kd}88ktS-�g4u5pT`tt 
%^�BRbS�(�|pCQ1!(�0D�tw)edx$m`oed(gidDqd
F�Tl`e�Rru�i��BzwQOeN|lr�omRt,v'6`b\w d�ags.c
 ")�f`maA|ym"(!��i[t"�C&b�wed�bran�h(0RA~ox
	&�(�6q,A�e��ac�:tas+'b3Qnchdpre^K8
?b��(sV{=#X�G&?q}ey 7CV2-Q��G]#�Nd�nS$6�tr�up`k�e�'�qgr`8
&`"->"- �-j+)
  (gr�%moUed�$+�p��T�* vhEg�7p`te�)JJ*("�w}ji#vR-olmbhbrW�lodg-%��yz��. �KAbK��9�n�fsi` iXe/g�&}iZ�2a�m@��ra�"(oxdg&Wmvj�e r!b	x$!sG�n\jD,	qroI0t rmr4cvsn�4�s"
��)c��a2�'�yg'*�! jliw$�,{61=Hdd-b2ef�hr{ml)p�"0�c�s1a�d5SL��f&�r�=pr�^cy�ppu�ox
�$`�({TS)kl!W�-}u(rQ1"�wR�uqd5%-�ģ�s&0b6S 'o�5pde�ub/nBfq()/$`�nL=,
,�b�!
 ,(#VS-mfte-%Ϊ2upD�tl�fla#s"n�l Cfc�vcs /(ҏm++��fkFt=mance'pi3C0T)<P *�u�|j-yvs=�D�iuvr,mfdu,�Gn�re ()_`"Avr`lF "i�$4,AVGF~0�f+gVeq6if(�edE���e�7)��|UHh� ol|�p )ohoZeq(f� %3 tiat0q�M�no| glag5aa0��hdS#kl�An73� Bx�l�dsi�ti�n9
;,do�qu (fi�uv۬�dy,-afcU6�'aWBksea� �� 8w+)�6s�!Ѱ~d/į-�wlu]$�e~#m�il%1l&o<�)r d@) �c*Rlnalazj&o�|�y*g�BI	��O$9)eui`v7M�)�%if$w,>�5bt9r�ƨ)"gMUV'dMR)+
   $}'tF%,c>f�fi<m�nn?7tAqe0w.*9BHYD��� )Ses-cp�anm�/wO|d}ct-]f #vs(q|]k+e� lm-�EiJ nil)J(�EbI�imobolu}�m�Y-cd�gN=ymhas=6cf{attunl?4o%��nOr�fs�wS3y�y�uh/pO	ygnise� �""<�'���4u&wn B>s-}/E-fIN`%y�E}}paur9'MnpN} '!
3uEl�DUBqk�ffer�e�4yKn�l�qxe�,`ma"iV a:�T�e2�Wm�Do?. b�*knum`l�uy�e(*L�sw6~Cs�$0tT/a�eta-
:2c29ON�t$nik� nal!#g*��)
-
�dem�n1!~2��K�e�pxx0X)9�?��%"(e� !�Wl��`e�"4dwgr@b|.pai�HvG"ph!felE�x~$An�zeIdY?fou�"J 99�t}rc�tu~��(<�kd (a �)�gp|t/-&gnd)F h�eq�iOruld;>d�F`vc�e('tov\-��$a�Y�i2
�dt�un0�bs)�od�-Es3&i]� hm)
,0b�9l� �l5 `�w*�
l()NMer�br9pe0j(ht$niru,!��uD�5SCJdh��`y~s-ode-nmf�6kle�E0�h`�-i

�)lnFqd Gv7--/��/k��/fA�g�jtio9,wI Dk -5!
0�&�`gw 4hE�$Imt0)�efmtx%:`�ihDo~~2 `(aj|Usce�i6i2hac41Da[7ioP?u'm�m)Di��`� �R/cfd,�i,d.Z�e(%!t$tki"� $�2qf k6�-$�jl5iodi& :Byk*"<g4h
u!md'"uNwe�N"! %,�7�GLxv%w	D) C~{9prk%�W�nil((cuP>�.4=Bunde�~�F:)Y!�"�r2�"d)b�0)�f0mff�k~f/-?z9ga&hml ` !8F/t+ceaz$ poA�p�}kn)��$� ig ;ra-s`cRa(9`gVve2E�(Gx|*|U�<+�w0	O�n%q-*	(s �hNG-t{=Fe%`sK�eqR%jsqsaJgr�+/+!�� 0p I9
&%v�f�tv?-o4u-f{*d(up|t x� "Or�Io
�l(gVhwT �e&_/� "_el5+�b� `u&nmr Cf~tcdka~-tlA "kwe*��d�(e�pre�x-rotenS9t(ebR'ter�i�`q�IOt��Z!�)>`n&") +i"��vACph?%�$i�t1�� pe)nfm4�ova^4dC�RBQl�pfefh�cR�!8*"�;Z�If1|cm$dvm.Pa|gdgs"�fm�,(�x$e� thi|!}? a�6�}@it(d} i�v#l	e no�AT9�n"
 HKhAJA��~$"(�1$(poh~�  hrVm�|  p.s.%3e�%�m�iu�.uveft)Ejo �9-0,�wi��)=�.Q(q *" ejt 8�dES (gE,~a\d<epot$�wy��]xos�e,G.T�Cit�~n#��+0� !("�� �#(� 0�`` r `0 (�  � � !" "! � ��o~u%l#/f�a-��0q�8  � `02c10�"��  P,dvr-�u-ldv,c:�lki|enq-e)����  E�do� "^o� #$F\$� na|D&!�i xKZ�l�D%!*$( 0mig"d9`��0tiomA,(�iw8#  �$(Igtu�dcthze�J.i���:cg�rmfl4.w�4 eOvs=bqc�C�Prefjx/i)
8 z/��l$Z (�vUc}0cuzr`�\?b1�&ep)+	( �(je@;C-lgd%�(�cd�(?im"lal ;�no t�	
 s �� �*�!e�(<bvS���neS{vk�>Txzuef�!!TITCHCT9�i p�)�a|1-�eab e�Wau�\*diz-cdovy���!8!( 8sU5�"�Efq|m|`��+tk6a:� �(kTs�]8p�no=p5t�bIe�`"cfa;�iE��ng--2�{vdnAh5!	(( �,�o{l�,(�8��@ls gt[nt/�g��ca� � �(4i?p`9obDbf!V@crld-fml�(nGbgl5r, de&augr*(2e�ugVx9))
�)� kt@Eb )&�:%d-of�7~=6a?Bog"`df�u~d%$Nekv�{qY�
		* p�0"I�{$(dAbmu,�o�M ecTo8y	l!�0� 35\se,#Ewees��~{%N�V;�  !p (cgtp lEbxtl0�`�r%"doZ���ir	)JI!i|e2*(bm`(YD$ztz�(#v�$r%�bH5vD-2mvira[?@i*VKt�
A ` �� �`&�?�kn!)~ns-lebU`G6t%ro�'�Fc�O>fq|=-�cme*ny<�(1� "D� faz!a�l2*ckFf,�(EQ�kvaQZ%nOjU�rm,egw$('d�2pldqm`Vt�ur)�H	$ e�d�g�	A0 "�J�vgd�6'>i�w=��"`�r<otngR/u(*$O�
)$!  gsripcl%t/�#uf.esi=vx�r,wiL,ow8i
�"�v0()fgi%� �6i�g=2uff,r /s~m�d�UO%�uF"rp����	� &! "aF9�( �(]|`.�
Q� cr�)fy�t-�a(Aejd-J�mp)gvqm�p`Lx�c"le%��h�gTfF�`i�%++*�0 ( Dh�ive)3'b�pL@4IEj
-� !0(w�def�O) ��(   *'w\�ic�`6 +�kknt5-�f))	!� "( �hfvc�a�E)|i,f$@4dCwa%dy�m�odx6(Le)))-B�!c56��+,**
ht}fub-��;-ma�% +kvY9i'u�-uf]o%bV@eQ@�(��,�gsm	0x'Une�doam�aN��A�tn �$L�-a3JG���ilps,��e`f}(e�a}vee/WB$`�n� !cfw�5xe	t  KXIE�"`��2RnN" 3;"��4;"|r%fi�
1�g1ME~u, TvO��6@&O��bv� ��	WY.z!�(jnt70�g\9�d ,lcyd(Ni�-iyx(���7%LleGs-qq'r�"g{r9�End�-�'aGs0&tne� �n��{f� " �f�gu2Vd.5m2refyz%za (canl,�ntMslc<�f$l!'#.s/+,$e�PmVfsv�8o	k�g
  bp!mq�*  ugs#6{9JO-b`mn�sf1'%hdo("�peS�E* a}'��4h2%aknEl�`h$"-rdaF(Fh)���) 6R `gs:fq ��~S$f�Lfy�~m,t{`uPbhcRe	TC�+�		����nd �uq$kkRc?eyl$�nbO.t[p�(&{�('��@UI�Z!
)!H$s hkBX�ILi&f�8�}"|ir�f)h &VMOFaL	)/)��  (g�q-{0l/p�2)fz-P1�ta�ign$�%oouAf� rk)A
�$ yfM%VGNO4AH�bi~('�p%stlht� I&!(�div-nt)E7y�b�p�wiu-�pnh�)A)K �2e( �ef��ns�lxfix/t�'39*�0v|eN(fis�emgved�*c4sm}k`e;�un"rd� ni�8bc�r�m~tUE)9��cv�}'�mmzuF`"58�ev� vdaosff�s�ot`gp
), !" `{�oS|Ys�oN�`h%�& ,�ne�@&]S-z%m^�e,  $0(�0 "p� 8`b ��$�dd(hl�ed�href�(buPV%�~%bfB$m�!J  !� �	 
!$ 0@     0��a#(l!EbL� hx'*b� )!0�   !  � $ ��! "�8�ipi-'�rSeJf}$nur�&vB
   (  ! !a2(�" �! �  (0B  )p7xsts-m�Ue-p�n #adj" ii�$j$S)w@dd�!�	i��)�)(�)0mefu�-cfs-�O`E! ���.g�e)P�6uS�/���rev(>"OO!O�*0��eR9$*R%f�r� qhf.caceOuDa �iM�W!t� "N olz2rt�1Y�o."
 p�[>�e2aCtqw- &��j){< @op�(��s=rƅfh�-oer!#�b�="�acH-p2L��8�J$$ $$\Meu  &sur{�z�=qx�dY�c�o g($) i
�d� h�$"c~36l!g3-1uD�y"eBv3!Ihdf-fArsi�,%+)i- h latj (,Vm3 )cTsndu)eAv�dD0WWA~Esp�"zwVuvu $*'i7E dk!
	�0} /0	CmnA�t �m8[@cx=r�c
�4-)kM!tEe�-��p�*/;)" �-1)0*�($dpsurre�lM:U�ber�
	0(und!s#hLA|Bda!*�
 !!`  ���8  0`d!#h(Wyt(m#rrUOt$te�nu`�bu�H40! 8+tw-e?4e	�T
 �Cg�!`lo�r�%>� �ccafi{)=)) I(�4dw��b�la� di�89�c  k()y�! �(  � #;u~�!|2vEn|�BUg�Ep!BeK p��jKr�)eode-r�j "uPt�een!(mI{4e�,�j�q`m vml#�r�v'	ba�	k5��$`o{T(c"ntaw��!;(H H$Qncw{8icde(�uD�v�c`%0�asV&\h`! fk�):p��tprk@Aepd�p�+)�N�d%feE-s7:�mo�Esus,<$�-��lutk/|/wK")J��eeX5�et�%0h�k[(�im� xHBr6WS�q alum�g9f>r.
ot�x�%t WjW�s�n"se dbnMU��u;.$o�bE�/�H�o�L`Be<|x�f#[n%y~P�!re!bO/P�nsu$%|Z�u wha`�fkcew�Tli���:$a���!|h` ��oB?s |eal.�J�0(in<dacti?q!�
4�m%*@i�d fav@=tkze�r{`(g6pe^pa,u�d)3	m%m$Rv!%�/c�&�di)
-(ln�ks (D�S`Cwcpy-�(=� t�vs1lv���zeD|ry"hif�!f�jNsk&&mHgmI}�ep��l�!"  &one�,)0 ("/o|(x}cYs��upp�2 6fy<�a�S$&m�%["
o�dd:)-h �@�  a�or�n/-q28�k�y��a6BE`�,Y��'l5�D�MoccQaqf �
cs�>�s{-�ol�"��J))	d$$ �$�eo�-sp�,,G�k�l?j[s	iz/Lje(,n�ae-Eyfe�2orilX(l�bh+ *dtlVt%d�pmCtpy �OC�	Xb` !$ niHe,| {p�7T lgo)�0t5o}�E-Fi�E`^�c+)/+9N+)=

� $efWv-3~�+�% Cv}/m/de���EmUu-jnd~a4$	-�`�"r�}Of%�hl�`li~	r!:jA|#a |&*a�d~mD�*��tt�)`isecP7qiespQ2aelsr�l>2" 0(i~Rdr�a|A4i)T0	g<�I.�A.wqecy�l��|pKF�#f�$bofmieb 4'3�Lb�Ns@V3)aw&�+ze-oVe�m}�mkxM�)%s1hANtne` t�)
*(fm64NJi^Q�~�a cvq-mofe? o�nku|%fgi`l9;  b�d�m�f �hl ia�k%�"f}jgspbìtH�"ru&foR$"K" h��v`rqgXHv-)�"8dohm�u Ifa1iav{�o%T�e��kd"�wrs��g~�gf=d#r�s�Q *%#"mwdeL'f#l$u+� "!()c6t�(hqw�-bi|eiFf��nt�]� Px�83T�D)	
$"�av�-s\Fa%5p,jwmlcty�aA�s�gwM+I��"�i,)LLli�i+J�tFbtZ!bds�pjo��ooZqD��k�tEv d/`UKooDE)w텂ill)�@`*�em��e+d�le{
) eEuvls!��/ic��of�Y�$thcr(sJbX<@ g54p{�c�5amgedl"
00 �-|*dy8bmmuc`(!~g=ode/mycog|��i,\V�stt�:c!xe%T.*hd�&$_.��b�)(
"�kis �j=2"9�cEparta4jog� luapda"8��I�	�~  |U1:itS=vo,eJ&d�?txpu(�i! ]~�o�W�*9I)`*�)TC�}od��}2ntdfId�%r0C=l�`	J	�#i8d�t xn��(xo��v�-W5h6o�i=r%inv1\s+J)�4" �)cV�-^ebyh(dq/b�e(jt�
	�	� (os!djou�"Fi,�-u\ist{�|
!)	 (h:b$^s)g�lejnfo=:f(|fmmu0f`()�I@&(  `0 Ctw��qLLba�hd	r gi �sev�/rm)l9 _)f{`ey!+	��litc�G :�v{%pe})"YbF�p)a9�  c �w�`x�n$ hOu"v�mwnF)b%qEw/(k��%C'��up-��ll^6elc"mhst)-$!$  �(wi�)��zr�~p-Cg&Cfa tmpR5bIher0�88irhycit;wAf%ldy`9�I� a�S%yosdt�%��z9^v�3*,e`cir83cTsMF)<ms�fmm7g]llejC~e�nysy!
	�!<�w{)R�pmq}f�Fe2,Sae�-r�i'�8C6v:ENT�b�fndp))
f!8s��yJu/�ine�2-+f-e�r�g�)t�an-`uvNM"+	m;
(0�(�� n�ku(ymx`qimcnd�	*anbn$-u�j�mgtn�H! ,d4x=dw�gr	fO7�
		" 0 (��lu�d�1~f)�a�"*$ej�`p <iv-q-!n�   !(Vc5b�"+| �gu!�)d\�z�w]�@o$r�N`�$(alet�")�)	r)f �)(5nGxh�r��p ` �Vg�-eR"� f�lfj$�2s~& ~ b
-��c!GtAR�I�($�  R�cmgylm!o�o-:g�lu�kpv$dgm�s)*(	I	$ (&?�Mct2�$sd� Omhfs9#2	L	$}.mpb�]�,	  >fc�es�)+)�( 18cVs�2tVy/)Q~ver!tpbuf�v1P�frer-) 	)TjsgO� hEs��� "�Do�|inf�)(niL�
1t   j$om�r`�ru fi<��i� deth`8�pYqg "cvq�fiLvy�6�-~|xr� "y	-j�$��1,8xG	.d( czg�2m�	�eo,~&5dX/�a)u 2h#)���� 7huj((o� �, "�� t�`$`$1�~�WL�(
"#`!��e� �fma)Yy~t3#p0gi�i 0jdeluV�+�ale%emh% ,
� )�$mU.de3�*aL,(ls�&`*br1*��leilfo=>{Tigh! &LE@D)�42=2/J!"b  #yq+h)J
)d�reJ-+wryMgde8g~q`ukde	re}cv`p"Rt�L�	 �Gl�s!("PimcrE
allpIibke�`�Eiew�eitl(Ybd�h|0rg)hNgm pb�%P6&�s0�63 �l!�cN"  ,yotEac�tivg(D�m�� i¶s-f.!Bs5pvez!'SUw-sm�ovw%gl!Ss"eVi reooJU1La��B�!`lg� ��.yS
�qt�ifo�0|-owa4grmw��e))-  !�8fv�dis#$@s�/l�De�R�kgrCg�s5"@,Coj� Blf"`�haF2! C`#)�`b!  0%gtq-b-�a�Yx�qoh�ebvi/n�c�y�cfooi%sHnaF�kI,2,)l�()��
H�d%fviz@cvs(tc�NA!$
c)
(p�ful%cVs-}�h%1xsuq�mO@mE��g ~"�YMR�E)2�4@f0&?�u�Lnhd&�$qg3)""*V,n&�fRy |b&���%'9o�#im���gL��<e�-�qxu�zW�4`!�ee`�z iz'W�eft, �rom�h86'�8J�s�f, aS�� �$dVF!T�l �hjc$�q,(n.lx hm�����`oH0DIseb�f)Mef
UY� qL
ogw�mod%�nr�%-k/-o#� !gj cIeo�i0��vs-�po]�t�v)da#&0"yBu�lMuv�<�(esm1kT$on�yxn9vid�a|pFi�5w"
`
8i,<ifiSvk~d�   �I[7"�sl1Q gV[-fi�u.Am�i� 0b�p(ivr�puex}�RE`! cra/ti/�dq�y1#tc�0na�L2(&P�dw=mup�odewa+>�G()1�(#vr-�lCg7-9�i�]tnub_aF=oduu�0 �#E�wla'3 !�  Cfr/%�f�=�O0*ty� y�`�8m&H:�|`�sixm)g�0Tq'�( # h �4.�(�f fu-njce%tiP-�fg;|�d	/�
�(dtfvk)#vp/�old +m/3!X�d�-}nxa8&"��MEi".qag $o�hoNpx >|agp�+jWTlb@c6p(Tew /f TI�6�/ A|d 7E$%C�vd4tad`sg.givh p2E~xs<�c}m�Ot�pzgMptDj�j!c�q`&,�icn"�&� k.d�raaTdve
��(9hYstH:3ua1 cf�-aA�VP}E"!�  �"�-crs)hug4y-2eed0kR�-���l�ai! bV�_3vm!tU,eTGj!3J� 000) `02 e$!((""    $b�"c�C>|%qpk�cd�sryd�e)�%�mvg-glEgs|q;e�; 'gDP4�w%f�cgc`*Dd� r�hoq�))2b,ARp,mDg-�O 2tag�0(C2xMEL�&�&m `  nmaga`�lise0�ag))p$ d� �(�hmh c69mvgRgkd{�mtcC ��ae�o9
+� B{vg`�{O@zlebi,eC�
 daF�f,6y-ge�cvS%m?Eebyl|=i�t)�l-oH.5�!(K" $"�5n`0y\e/3oluk�cnhdE"?j�Ilu �exesud(��tm��qpx�:t�g `den�n�n� h)nT�saaire�h��|�pp((E�r)�ed6w�oe�-xq`ku$ (vV-kvln>�oGV9_x !�y\a-b/mXKl$'!kz���h! i�O/I�p!��h)-�rkL@,J  $$ $(��&(9��kde�q�e )c0q=NlDuin~w%>n�-�Jau!Th(+88�hml"ys�i�g)M)v+Kp"\T>e~UN%.��ilMF�^�;0ajite+sfe�id���,� bi[��hme(�"�k+�;+ sheno$/of�qwp`es|.�(�e�Tij$a�(m,{-�wnfer#'IYg-�g�%-fvd�4hm
�(�EF5n-cWSmln�1vqm���5ifm=1`]n�%)LKc-�.�dȽ�:hi>(�Jlt�x b�d\�`=d�jgu\�f$%v0q(oz"hiCo.gDMjg of(&h�2"urc,eT�i�m'tsq/b$&Hin�e@Ag|)|�)�(y? StqeCVW0iaf)loo a8�,maiyh94�bdEa/se4k$&	|b$eTrv�5�oLnae�p!SHio sE(#C�m*%br;,�.D=c:ijhe~>gd�pry�Gtz�rmw]ndI�b$E�y, $H} h�;hCdd=�e-*]vgE�fyl-nAoe-function ends up unbound when we leave the `let'.
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
