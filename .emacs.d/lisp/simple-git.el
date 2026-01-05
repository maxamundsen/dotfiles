;;; simple-git.el --- Simple Git interface for Emacs  -*- lexical-binding: t; -*-

;; Author: Max Amundsen
;; Version: 1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: git, vc, tools

;;; Commentary:
;; A lightweight Git interface providing:
;; - Status view with staging/unstaging
;; - Commit with message
;; - Push/pull
;; - Commit history log

;;; Code:

(require 'cl-lib)

;;; ============================================================================
;;; Customization
;;; ============================================================================

(defgroup simple-git nil
  "Simple Git interface."
  :group 'tools
  :prefix "simple-git-")

(defface simple-git-header-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for headers in simple-git buffers.")

(defface simple-git-staged-face
  '((t :inherit font-lock-string-face))
  "Face for staged files.")

(defface simple-git-unstaged-face
  '((t :inherit font-lock-warning-face))
  "Face for unstaged/modified files.")

(defface simple-git-untracked-face
  '((t :inherit font-lock-comment-face))
  "Face for untracked files.")

(defface simple-git-commit-hash-face
  '((t :inherit font-lock-constant-face))
  "Face for commit hashes.")

(defface simple-git-commit-author-face
  '((t :inherit font-lock-type-face))
  "Face for commit authors.")

(defface simple-git-commit-date-face
  '((t :inherit font-lock-comment-face))
  "Face for commit dates.")

;;; ============================================================================
;;; Utility Functions
;;; ============================================================================

(defun simple-git--root ()
  "Get the root directory of the current Git repository."
  (let ((root (locate-dominating-file default-directory ".git")))
    (when root (expand-file-name root))))

(defun simple-git--run (&rest args)
  "Run git command with ARGS and return output as string."
  (let ((default-directory (or (simple-git--root) default-directory)))
    (with-temp-buffer
      (apply #'call-process "git" nil t nil args)
      (buffer-string))))

(defun simple-git--run-async (callback &rest args)
  "Run git command with ARGS asynchronously, call CALLBACK with output."
  (let* ((default-directory (or (simple-git--root) default-directory))
         (buf (generate-new-buffer " *simple-git-async*"))
         (proc (apply #'start-process "simple-git" buf "git" args)))
    (set-process-sentinel
     proc
     (lambda (p _event)
       (when (eq (process-status p) 'exit)
         (with-current-buffer (process-buffer p)
           (funcall callback (buffer-string)))
         (kill-buffer (process-buffer p)))))))

(defun simple-git--in-repo-p ()
  "Return non-nil if current directory is in a Git repository."
  (simple-git--root))

;;; ============================================================================
;;; Mouse Support
;;; ============================================================================

(defface simple-git-highlight-face
  '((t :inherit highlight))
  "Face for mouse hover on clickable items.")

(defun simple-git-mouse-action (event)
  "Perform default action at mouse click EVENT."
  (interactive "e")
  (mouse-set-point event)
  (let ((cmd (lookup-key (current-local-map) (kbd "RET"))))
    (when cmd
      (call-interactively cmd))))

(defun simple-git-mouse-visit-file (event)
  "Visit file at mouse click EVENT."
  (interactive "e")
  (mouse-set-point event)
  (simple-git-visit-file))

;;; ============================================================================
;;; Status Mode
;;; ============================================================================

(defvar simple-git-status-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'simple-git-status-refresh)
    (define-key map (kbd "s") #'simple-git-stage-file)
    (define-key map (kbd "u") #'simple-git-unstage-file)
    (define-key map (kbd "S") #'simple-git-stage-all)
    (define-key map (kbd "U") #'simple-git-unstage-all)
    (define-key map (kbd "r") #'simple-git-revert-file)
    (define-key map (kbd "c") #'simple-git-commit)
    (define-key map (kbd "P") #'simple-git-push)
    (define-key map (kbd "F") #'simple-git-pull)
    (define-key map (kbd "b") #'simple-git-switch-branch)
    (define-key map (kbd "G") #'simple-git-branch-graph)
    (define-key map (kbd "l") #'simple-git-log)
    (define-key map (kbd "v") #'simple-git-visit-file)
    (define-key map (kbd "m") #'simple-git-merge)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "RET") #'simple-git-diff-file)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
    (define-key map [mouse-1] #'simple-git-mouse-action)
    (define-key map [C-mouse-1] #'simple-git-mouse-visit-file)
    map)
  "Keymap for `simple-git-status-mode'.")

(define-derived-mode simple-git-status-mode special-mode "SimpleGit:Status"
  "Major mode for simple-git status buffer."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defun simple-git--parse-status ()
  "Parse git status --porcelain output into structured data."
  (let ((output (simple-git--run "status" "--porcelain" "-uall"))
        staged unstaged untracked)
    (dolist (line (split-string output "\n" t))
      (when (>= (length line) 3)
        (let ((index-status (aref line 0))
              (worktree-status (aref line 1))
              (file (substring line 3)))
          (cond
           ;; Staged changes
           ((and (not (eq index-status ?\s))
                 (not (eq index-status ??)))
            (push (cons file (char-to-string index-status)) staged))
           ;; Untracked
           ((eq index-status ??)
            (push file untracked))
           ;; Unstaged modifications
           ((and (eq index-status ?\s)
                 (not (eq worktree-status ?\s)))
            (push (cons file (char-to-string worktree-status)) unstaged)))
          ;; Handle files that are both staged and have unstaged changes
          (when (and (not (eq index-status ?\s))
                     (not (eq index-status ??))
                     (not (eq worktree-status ?\s)))
            (push (cons file (char-to-string worktree-status)) unstaged)))))
    (list :staged (nreverse staged)
          :unstaged (nreverse unstaged)
          :untracked (nreverse untracked))))

(defun simple-git--get-branch ()
  "Get current branch name."
  (string-trim (simple-git--run "rev-parse" "--abbrev-ref" "HEAD")))

(defun simple-git--get-remote-status ()
  "Get ahead/behind status relative to remote."
  (let* ((branch (simple-git--get-branch))
         (remote-ref (format "origin/%s" branch))
         (output (simple-git--run "rev-list" "--left-right" "--count"
                                  (format "%s...%s" branch remote-ref))))
    (when (string-match "\\([0-9]+\\)\\s-+\\([0-9]+\\)" output)
      (let ((ahead (string-to-number (match-string 1 output)))
            (behind (string-to-number (match-string 2 output))))
        (cond
         ((and (> ahead 0) (> behind 0))
          (format " [ahead %d, behind %d]" ahead behind))
         ((> ahead 0)
          (format " [ahead %d]" ahead))
         ((> behind 0)
          (format " [behind %d]" behind))
         (t ""))))))

(defun simple-git-status-refresh ()
  "Refresh the status buffer."
  (interactive)
  (when (eq major-mode 'simple-git-status-mode)
    (let ((inhibit-read-only t)
          (pos (point))
          (status (simple-git--parse-status))
          (branch (simple-git--get-branch))
          (remote-status (or (simple-git--get-remote-status) "")))
      (erase-buffer)
      ;; Header
      (insert (propertize (format "Git Status: %s" (simple-git--root))
                          'face 'simple-git-header-face)
              "\n")
      (insert (propertize (format "Branch: %s%s" branch remote-status)
                          'face 'simple-git-header-face)
              "\n\n")
      ;; Help
      (insert "Commands: ")
      (insert (propertize "RET" 'face 'font-lock-keyword-face) " diff  ")
      (insert (propertize "v" 'face 'font-lock-keyword-face) "iew file  ")
      (insert (propertize "s" 'face 'font-lock-keyword-face) "tage  ")
      (insert (propertize "u" 'face 'font-lock-keyword-face) "nstage  ")
      (insert (propertize "S" 'face 'font-lock-keyword-face) "tage-all  ")
      (insert (propertize "U" 'face 'font-lock-keyword-face) "nstage-all  ")
      (insert (propertize "c" 'face 'font-lock-keyword-face) "ommit  ")
      (insert (propertize "P" 'face 'font-lock-keyword-face) "ush  ")
      (insert (propertize "F" 'face 'font-lock-keyword-face) "etch/pull  ")
      (insert (propertize "b" 'face 'font-lock-keyword-face) "ranch  ")
      (insert (propertize "G" 'face 'font-lock-keyword-face) "raph  ")
      (insert (propertize "l" 'face 'font-lock-keyword-face) "og  ")
      (insert (propertize "m" 'face 'font-lock-keyword-face) "erge  ")
      (insert (propertize "r" 'face 'font-lock-keyword-face) "evert  ")
      (insert (propertize "g" 'face 'font-lock-keyword-face) " refresh  ")
      (insert (propertize "q" 'face 'font-lock-keyword-face) "uit")
      (insert "\n\n")
      ;; Staged files
      (let ((staged (plist-get status :staged)))
        (insert (propertize (format "Staged (%d):\n" (length staged))
                            'face 'simple-git-header-face))
        (if staged
            (dolist (item staged)
              (let ((line-start (point)))
                (insert "  " (propertize (format "[%s] " (cdr item))
                                         'face 'simple-git-staged-face)
                        (propertize (car item) 'face 'simple-git-staged-face)
                        "\n")
                (put-text-property line-start (1- (point)) 'simple-git-file (car item))
                (put-text-property line-start (1- (point)) 'simple-git-staged t)
                (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))
          (insert "  (none)\n")))
      (insert "\n")
      ;; Unstaged files
      (let ((unstaged (plist-get status :unstaged)))
        (insert (propertize (format "Unstaged (%d):\n" (length unstaged))
                            'face 'simple-git-header-face))
        (if unstaged
            (dolist (item unstaged)
              (let ((line-start (point)))
                (insert "  " (propertize (format "[%s] " (cdr item))
                                         'face 'simple-git-unstaged-face)
                        (propertize (car item) 'face 'simple-git-unstaged-face)
                        "\n")
                (put-text-property line-start (1- (point)) 'simple-git-file (car item))
                (put-text-property line-start (1- (point)) 'simple-git-staged nil)
                (put-text-property line-start (1- (point)) 'simple-git-unstaged t)
                (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))
          (insert "  (none)\n")))
      (insert "\n")
      ;; Untracked files
      (let ((untracked (plist-get status :untracked)))
        (insert (propertize (format "Untracked (%d):\n" (length untracked))
                            'face 'simple-git-header-face))
        (if untracked
            (dolist (file untracked)
              (let ((line-start (point)))
                (insert "  " (propertize file 'face 'simple-git-untracked-face)
                        "\n")
                (put-text-property line-start (1- (point)) 'simple-git-file file)
                (put-text-property line-start (1- (point)) 'simple-git-untracked t)
                (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))
          (insert "  (none)\n")))
      (goto-char (min pos (point-max))))))

(defun simple-git--file-at-point ()
  "Get the file path at point."
  (get-text-property (line-beginning-position) 'simple-git-file))

(defun simple-git--staged-at-point ()
  "Return t if file at point is staged."
  (get-text-property (line-beginning-position) 'simple-git-staged))

(defun simple-git--unstaged-at-point ()
  "Return t if file at point is unstaged (modified but not staged)."
  (get-text-property (line-beginning-position) 'simple-git-unstaged))

(defun simple-git--untracked-at-point ()
  "Return t if file at point is untracked."
  (get-text-property (line-beginning-position) 'simple-git-untracked))

(defun simple-git-stage-file ()
  "Stage the file at point."
  (interactive)
  (if-let ((file (simple-git--file-at-point)))
      (let ((default-directory (simple-git--root)))
        (simple-git--run "add" "--" file)
        (simple-git-status-refresh)
        (message "Staged: %s" file))
    (message "No file at point")))

(defun simple-git-unstage-file ()
  "Unstage the file at point."
  (interactive)
  (if-let ((file (simple-git--file-at-point)))
      (if (simple-git--staged-at-point)
          (let ((default-directory (simple-git--root)))
            (simple-git--run "reset" "HEAD" "--" file)
            (simple-git-status-refresh)
            (message "Unstaged: %s" file))
        (message "File is not staged"))
    (message "No file at point")))

(defun simple-git-revert-file ()
  "Revert unstaged changes in file at point (restore to last committed state)."
  (interactive)
  (if-let ((file (simple-git--file-at-point)))
      (cond
       ((simple-git--untracked-at-point)
        (message "Cannot revert untracked file (use delete instead)"))
       ((simple-git--staged-at-point)
        (message "Cannot revert staged file (unstage first)"))
       ((simple-git--unstaged-at-point)
        (if (yes-or-no-p (format "Revert changes to %s? " file))
            (let ((default-directory (simple-git--root)))
              (simple-git--run "checkout" "--" file)
              (simple-git-status-refresh)
              (message "Reverted: %s" file))
          (message "Revert cancelled")))
       (t
        (message "No unstaged changes to revert")))
    (message "No file at point")))

(defun simple-git-stage-all ()
  "Stage all changes."
  (interactive)
  (simple-git--run "add" "-A")
  (simple-git-status-refresh)
  (message "Staged all changes"))

(defun simple-git-unstage-all ()
  "Unstage all changes."
  (interactive)
  (simple-git--run "reset" "HEAD")
  (simple-git-status-refresh)
  (message "Unstaged all changes"))

(defun simple-git-diff-file ()
  "Show diff for file at point."
  (interactive)
  (if-let ((file (simple-git--file-at-point)))
      (let ((buf (get-buffer-create "*simple-git-diff*"))
            (staged (simple-git--staged-at-point))
            (root (simple-git--root)))
        (with-current-buffer buf
          (let ((inhibit-read-only t)
                (default-directory root))
            (erase-buffer)
            (if staged
                (call-process "git" nil t nil "diff" "--cached" "--" file)
              (call-process "git" nil t nil "diff" "--" file))
            (goto-char (point-min))
            (diff-mode)
            (setq buffer-read-only t)))
        (display-buffer buf))
    (message "No file at point")))

(defun simple-git-visit-file ()
  "Visit the file at point."
  (interactive)
  (when-let ((file (simple-git--file-at-point)))
    (find-file (expand-file-name file (simple-git--root)))))

;;; ============================================================================
;;; Commit
;;; ============================================================================

(defvar simple-git--commit-window-config nil
  "Window configuration before entering commit message.")

(defvar simple-git-commit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-s") #'simple-git-commit-finish)
    (define-key map (kbd "C-g") #'simple-git-commit-cancel)
    map)
  "Keymap for `simple-git-commit-mode'.")

(define-derived-mode simple-git-commit-mode text-mode "SimpleGit:Commit"
  "Major mode for writing commit messages."
  (setq-local header-line-format
              "Commit message. C-s to commit, C-g to cancel."))

(defun simple-git-commit ()
  "Start composing a commit message."
  (interactive)
  (let ((status (simple-git--parse-status)))
    (if (null (plist-get status :staged))
        (message "Nothing staged to commit")
      (setq simple-git--commit-window-config (current-window-configuration))
      (let ((buf (get-buffer-create "*simple-git-commit*")))
        (pop-to-buffer buf)
        (erase-buffer)
        (simple-git-commit-mode)
        (insert "\n\n# Enter commit message above.\n# Lines starting with '#' will be ignored.\n#\n# Changes to be committed:\n")
        (dolist (item (plist-get status :staged))
          (insert (format "#   %s: %s\n" (cdr item) (car item))))
        (goto-char (point-min))))))

(defun simple-git-commit-finish ()
  "Finish the commit with the current message."
  (interactive)
  (let* ((content (buffer-string))
         (lines (split-string content "\n"))
         (message-lines (cl-remove-if (lambda (l) (string-prefix-p "#" l)) lines))
         (message (string-trim (mapconcat #'identity message-lines "\n"))))
    (if (string-empty-p message)
        (message "Aborting commit due to empty message")
      (let ((default-directory (simple-git--root)))
        (with-temp-buffer
          (call-process "git" nil t nil "commit" "-m" message)
          (message "%s" (string-trim (buffer-string)))))
      (kill-buffer)
      (when simple-git--commit-window-config
        (set-window-configuration simple-git--commit-window-config)
        (setq simple-git--commit-window-config nil))
      (when (get-buffer "*simple-git-status*")
        (with-current-buffer "*simple-git-status*"
          (simple-git-status-refresh))))))

(defun simple-git-commit-cancel ()
  "Cancel the commit."
  (interactive)
  (kill-buffer)
  (when simple-git--commit-window-config
    (set-window-configuration simple-git--commit-window-config)
    (setq simple-git--commit-window-config nil))
  (message "Commit cancelled"))

;;; ============================================================================
;;; Push / Pull
;;; ============================================================================

(defun simple-git-push ()
  "Push to remote."
  (interactive)
  (let ((branch (simple-git--get-branch)))
    (message "Pushing %s to origin..." branch)
    (simple-git--run-async
     (lambda (output)
       (message "%s" (string-trim output))
       (when (get-buffer "*simple-git-status*")
         (with-current-buffer "*simple-git-status*"
           (simple-git-status-refresh))))
     "push" "-u" "origin" branch)))

(defun simple-git-pull ()
  "Pull from remote."
  (interactive)
  (message "Pulling from origin...")
  (simple-git--run-async
   (lambda (output)
     (message "%s" (string-trim output))
     (when (get-buffer "*simple-git-status*")
       (with-current-buffer "*simple-git-status*"
         (simple-git-status-refresh))))
   "pull"))

;;; ============================================================================
;;; Branch
;;; ============================================================================

(defun simple-git--list-branches ()
  "Return list of all branches (local and remote)."
  (let* ((output (simple-git--run "branch" "-a" "--format=%(refname:short)"))
         (branches (split-string output "\n" t)))
    ;; Remove duplicates and clean up remote branch names
    (delete-dups
     (mapcar (lambda (b)
               (if (string-prefix-p "origin/" b)
                   (substring b 7)
                 b))
             branches))))

(defun simple-git-switch-branch ()
  "Switch to a different branch using completion."
  (interactive)
  (let* ((branches (simple-git--list-branches))
         (current (simple-git--get-branch))
         (branches-sorted (cons current (delete current branches)))
         (choice (completing-read
                  (format "Switch branch (current: %s): " current)
                  branches-sorted nil nil nil nil current)))
    (if (string= choice current)
        (message "Already on branch %s" current)
      (let* ((default-directory (simple-git--root))
             (output (simple-git--run "checkout" choice)))
        (message "%s" (string-trim output))
        (when (get-buffer "*simple-git-status*")
          (with-current-buffer "*simple-git-status*"
            (simple-git-status-refresh)))))))

(defun simple-git-merge ()
  "Merge another branch into the current branch."
  (interactive)
  (let* ((branches (simple-git--list-branches))
         (current (simple-git--get-branch))
         (other-branches (delete current (copy-sequence branches)))
         (choice (completing-read
                  (format "Merge into %s from: " current)
                  other-branches nil t)))
    (when (and choice (not (string-empty-p choice)))
      (let* ((default-directory (simple-git--root))
             (output (simple-git--run "merge" choice)))
        (message "%s" (string-trim output))
        (when (get-buffer "*simple-git-status*")
          (with-current-buffer "*simple-git-status*"
            (simple-git-status-refresh)))))))

;;; ============================================================================
;;; Log Mode
;;; ============================================================================

(defvar simple-git-log-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'simple-git-log-show-commit)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "g") #'simple-git-log-refresh)
    (define-key map (kbd "n") #'simple-git-log-next-page)
    (define-key map (kbd "p") #'simple-git-log-prev-page)
    (define-key map (kbd "N") #'simple-git-log-last-page)
    (define-key map (kbd "P") #'simple-git-log-first-page)
    (define-key map [mouse-1] #'simple-git-mouse-action)
    map)
  "Keymap for `simple-git-log-mode'.")

(define-derived-mode simple-git-log-mode special-mode "SimpleGit:Log"
  "Major mode for simple-git log buffer."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defvar simple-git-log-count 50
  "Number of commits to show per page in log.")

(defvar-local simple-git--log-page 0
  "Current page number in log view.")

(defvar-local simple-git--log-total-commits nil
  "Total number of commits in log.")

(defun simple-git--get-total-commits ()
  "Get total number of commits in repository."
  (string-to-number (string-trim (simple-git--run "rev-list" "--count" "HEAD"))))

(defun simple-git-log-refresh ()
  "Refresh the log buffer."
  (interactive)
  (when (eq major-mode 'simple-git-log-mode)
    (let ((inhibit-read-only t)
          (pos (point))
          (default-directory (simple-git--root))
          (skip (* simple-git--log-page simple-git-log-count)))
      ;; Get total commits if not cached
      (unless simple-git--log-total-commits
        (setq simple-git--log-total-commits (simple-git--get-total-commits)))
      (let ((max-page (max 0 (1- (ceiling (/ (float simple-git--log-total-commits) simple-git-log-count))))))
        ;; Cap page number
        (when (> simple-git--log-page max-page)
          (setq simple-git--log-page max-page)
          (setq skip (* simple-git--log-page simple-git-log-count)))
        (erase-buffer)
        (insert (propertize "Commit History" 'face 'simple-git-header-face)
                (format " (page %d/%d)" (1+ simple-git--log-page) (1+ max-page))
                "\n")
        (insert "Commands: "
                (propertize "RET" 'face 'font-lock-keyword-face) " show commit  "
                (propertize "n" 'face 'font-lock-keyword-face) "ext page  "
                (propertize "p" 'face 'font-lock-keyword-face) "rev page  "
                (propertize "N" 'face 'font-lock-keyword-face) " last  "
                (propertize "P" 'face 'font-lock-keyword-face) " first  "
                (propertize "g" 'face 'font-lock-keyword-face) " refresh  "
                (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
        (let ((output (simple-git--run "log"
                                       (format "--skip=%d" skip)
                                       (format "-n%d" simple-git-log-count)
                                       "--pretty=format:%h|%an|%ar|%s")))
          (dolist (line (split-string output "\n" t))
            (let* ((parts (split-string line "|"))
                   (hash (nth 0 parts))
                   (author (nth 1 parts))
                   (date (nth 2 parts))
                   (subject (nth 3 parts))
                   (line-start (point)))
              (insert (propertize hash 'face 'simple-git-commit-hash-face
                                  'simple-git-commit hash)
                      " "
                      (propertize (format "%-20s" (truncate-string-to-width (or author "") 20))
                                  'face 'simple-git-commit-author-face)
                      " "
                      (propertize (format "%-15s" (truncate-string-to-width (or date "") 15))
                                  'face 'simple-git-commit-date-face)
                      " "
                      (or subject "")
                      "\n")
              (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))))
      (goto-char (min pos (point-max))))))

(defun simple-git-log-next-page ()
  "Go to next page of log."
  (interactive)
  (setq simple-git--log-page (1+ simple-git--log-page))
  (simple-git-log-refresh))

(defun simple-git-log-prev-page ()
  "Go to previous page of log."
  (interactive)
  (when (> simple-git--log-page 0)
    (setq simple-git--log-page (1- simple-git--log-page))
    (simple-git-log-refresh)))

(defun simple-git-log-first-page ()
  "Go to first page of log."
  (interactive)
  (setq simple-git--log-page 0)
  (simple-git-log-refresh))

(defun simple-git-log-last-page ()
  "Go to last page of log."
  (interactive)
  (unless simple-git--log-total-commits
    (setq simple-git--log-total-commits (simple-git--get-total-commits)))
  (setq simple-git--log-page (max 0 (1- (ceiling (/ (float simple-git--log-total-commits) simple-git-log-count)))))
  (simple-git-log-refresh))

(defun simple-git--commit-at-point ()
  "Get the commit hash at point."
  (get-text-property (line-beginning-position) 'simple-git-commit))

;;; ============================================================================
;;; Commit Detail Mode
;;; ============================================================================

(defvar simple-git-commit-detail-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'simple-git-show-file-diff)
    (define-key map (kbd "v") #'simple-git-commit-view-file)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
    (define-key map [mouse-1] #'simple-git-mouse-action)
    map)
  "Keymap for `simple-git-commit-detail-mode'.")

(define-derived-mode simple-git-commit-detail-mode special-mode "SimpleGit:Commit"
  "Major mode for viewing commit details with expandable file diffs."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defun simple-git-log-show-commit ()
  "Show the commit at point with per-file breakdown."
  (interactive)
  (when-let ((hash (simple-git--commit-at-point)))
    (let ((buf (get-buffer-create "*simple-git-commit-detail*"))
          (root (simple-git--root)))
      (with-current-buffer buf
        (let ((inhibit-read-only t)
              (default-directory root))
          (erase-buffer)
          ;; Get commit info
          (let* ((info (simple-git--run "show" "--no-patch"
                                        "--format=%h%n%an%n%ar%n%s%n%b" hash))
                 (lines (split-string info "\n"))
                 (short-hash (nth 0 lines))
                 (author (nth 1 lines))
                 (date (nth 2 lines))
                 (subject (nth 3 lines))
                 (body (string-trim (mapconcat #'identity (nthcdr 4 lines) "\n"))))
            ;; Header
            (insert (propertize "Commit: " 'face 'simple-git-header-face)
                    (propertize short-hash 'face 'simple-git-commit-hash-face) "\n")
            (insert (propertize "Author: " 'face 'simple-git-header-face)
                    (propertize author 'face 'simple-git-commit-author-face) "\n")
            (insert (propertize "Date:   " 'face 'simple-git-header-face)
                    (propertize date 'face 'simple-git-commit-date-face) "\n\n")
            (insert (propertize subject 'face 'bold) "\n")
            (when (not (string-empty-p body))
              (insert "\n" body "\n"))
            (insert "\n")
            (insert "Commands: "
                    (propertize "RET" 'face 'font-lock-keyword-face) " show diff  "
                    (propertize "v" 'face 'font-lock-keyword-face) "iew file at this point  "
                    (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
            ;; Get list of changed files
            (let* ((files-output (simple-git--run "show" "--name-status" "--format=" hash))
                   (file-lines (split-string files-output "\n" t)))
              (insert (propertize "Changed files:\n" 'face 'simple-git-header-face))
              (dolist (file-line file-lines)
                (when (string-match "^\\([AMDRT]\\)\t\\(.+\\)$" file-line)
                  (let ((status (match-string 1 file-line))
                        (file (match-string 2 file-line)))
                    (let ((line-start (point)))
                      (insert "  "
                              (propertize (format "[%s] " status)
                                          'face (pcase status
                                                  ("A" 'simple-git-staged-face)
                                                  ("D" 'simple-git-unstaged-face)
                                                  (_ 'simple-git-untracked-face)))
                              file "\n")
                      (put-text-property line-start (1- (point)) 'simple-git-commit-file file)
                      (put-text-property line-start (1- (point)) 'simple-git-commit-hash hash)
                      (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face))))))))
        (simple-git-commit-detail-mode)
        (goto-char (point-min)))
      (display-buffer buf))))

(defun simple-git--file-at-point-commit ()
  "Get file and commit hash at point in commit detail buffer."
  (list (get-text-property (line-beginning-position) 'simple-git-commit-file)
        (get-text-property (line-beginning-position) 'simple-git-commit-hash)))

(defun simple-git-commit-view-file ()
  "Open the file at point as it was at that commit."
  (interactive)
  (let* ((info (simple-git--file-at-point-commit))
         (file (nth 0 info))
         (hash (nth 1 info)))
    (if (and file hash)
        (let* ((root (simple-git--root))
               (buf-name (format "*simple-git:%s@%s*" (file-name-nondirectory file) hash))
               (buf (get-buffer-create buf-name)))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (call-process "git" nil t nil "show" (concat hash ":" file))
              (goto-char (point-min))
              ;; Set mode based on file extension
              (let ((mode (assoc-default file auto-mode-alist 'string-match)))
                (when mode (funcall mode)))
              (setq buffer-read-only t)))
          ;; Display in main window, not side window
          (let ((main-window (or (seq-find (lambda (w)
                                             (not (window-parameter w 'window-side)))
                                           (window-list))
                                 (selected-window))))
            (select-window main-window)
            (switch-to-buffer buf)))
      (message "No file at point"))))

(defvar simple-git-diff-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'simple-git-diff-quit)
    (define-key map (kbd "n") #'diff-hunk-next)
    (define-key map (kbd "p") #'diff-hunk-prev)
    map)
  "Keymap for `simple-git-diff-mode'.")

(define-derived-mode simple-git-diff-mode diff-mode "SimpleGit:Diff"
  "Major mode for viewing diffs with simple-git."
  (setq buffer-read-only t))

(defvar-local simple-git--diff-return-buffer nil
  "Buffer to return to when quitting diff.")

(defun simple-git-diff-quit ()
  "Quit diff and return to previous buffer."
  (interactive)
  (let ((return-buf simple-git--diff-return-buffer))
    (quit-window)
    (when (and return-buf (buffer-live-p return-buf))
      (pop-to-buffer return-buf))))

(defun simple-git-show-file-diff ()
  "Show diff for file at point in a separate buffer."
  (interactive)
  (let* ((info (simple-git--file-at-point-commit))
         (file (nth 0 info))
         (hash (nth 1 info))
         (return-buf (current-buffer)))
    (if (and file hash)
        (let ((buf (get-buffer-create "*simple-git-diff*"))
              (root (simple-git--root)))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (call-process "git" nil t nil "show" "--format=" hash "--" file)
              (goto-char (point-min))
              (simple-git-diff-mode)
              (setq simple-git--diff-return-buffer return-buf)))
          (display-buffer buf))
      (message "No file at point"))))

;;;###autoload
(defun simple-git-log ()
  "Show Git commit history."
  (interactive)
  (unless (simple-git--in-repo-p)
    (user-error "Not in a Git repository"))
  (let ((buf (get-buffer-create "*simple-git-log*")))
    (with-current-buffer buf
      (simple-git-log-mode)
      (simple-git-log-refresh))
    (pop-to-buffer buf)))

;;; ============================================================================
;;; File History Mode
;;; ============================================================================

(defvar simple-git-file-history-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'simple-git-file-history-show-diff)
    (define-key map (kbd "v") #'simple-git-file-history-view-file)
    (define-key map (kbd "c") #'simple-git-file-history-show-commit)
    (define-key map (kbd "n") #'simple-git-file-history-next-page)
    (define-key map (kbd "p") #'simple-git-file-history-prev-page)
    (define-key map (kbd "N") #'simple-git-file-history-last-page)
    (define-key map (kbd "P") #'simple-git-file-history-first-page)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "g") #'simple-git-file-history-refresh)
    (define-key map [mouse-1] #'simple-git-mouse-action)
    map)
  "Keymap for `simple-git-file-history-mode'.")

(define-derived-mode simple-git-file-history-mode special-mode "SimpleGit:FileHistory"
  "Major mode for viewing file history."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defvar-local simple-git--file-history-file nil
  "The file being viewed in file history mode.")

(defvar-local simple-git--file-history-root nil
  "The git root for file history mode.")

(defvar-local simple-git--file-history-page 0
  "Current page number in file history view.")

(defvar-local simple-git--file-history-total-commits nil
  "Total number of commits for file.")

(defun simple-git--get-file-total-commits (file)
  "Get total number of commits for FILE."
  (string-to-number (string-trim (simple-git--run "rev-list" "--count" "--follow" "HEAD" "--" file))))

(defun simple-git-file-history-refresh ()
  "Refresh the file history buffer."
  (interactive)
  (when (eq major-mode 'simple-git-file-history-mode)
    (let ((inhibit-read-only t)
          (pos (point))
          (file simple-git--file-history-file)
          (root simple-git--file-history-root)
          (skip (* simple-git--file-history-page simple-git-log-count)))
      ;; Get total commits if not cached
      (let ((default-directory root))
        (unless simple-git--file-history-total-commits
          (setq simple-git--file-history-total-commits (simple-git--get-file-total-commits file))))
      (let ((max-page (max 0 (1- (ceiling (/ (float simple-git--file-history-total-commits) simple-git-log-count))))))
        ;; Cap page number
        (when (> simple-git--file-history-page max-page)
          (setq simple-git--file-history-page max-page)
          (setq skip (* simple-git--file-history-page simple-git-log-count)))
        (erase-buffer)
        (insert (propertize "File History" 'face 'simple-git-header-face)
                (format " (page %d/%d)" (1+ simple-git--file-history-page) (1+ max-page))
                "\n")
        (insert (propertize "File: " 'face 'simple-git-header-face)
                file "\n\n")
        (insert "Commands: "
                (propertize "RET" 'face 'font-lock-keyword-face) " show diff  "
                (propertize "v" 'face 'font-lock-keyword-face) "iew file at this point  "
                (propertize "c" 'face 'font-lock-keyword-face) "ommit view  "
                (propertize "n" 'face 'font-lock-keyword-face) "ext page  "
                (propertize "p" 'face 'font-lock-keyword-face) "rev page  "
                (propertize "N" 'face 'font-lock-keyword-face) " last  "
                (propertize "P" 'face 'font-lock-keyword-face) " first  "
                (propertize "g" 'face 'font-lock-keyword-face) " refresh  "
                (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
        ;; Get log with file names to track renames
        (let* ((default-directory root)
               (output (simple-git--run "log" "--follow" "--name-status"
                                        (format "--skip=%d" skip)
                                        (format "-n%d" simple-git-log-count)
                                        "--pretty=format:%h|%an|%ar|%s"
                                        "--" file))
             (lines (split-string output "\n"))
             (current-file file))
        ;; Parse output - each commit has format line, then blank, then file status
        (let ((i 0))
          (while (< i (length lines))
            (let ((line (nth i lines)))
              (when (string-match "^\\([a-f0-9]+\\)|\\(.*\\)|\\(.*\\)|\\(.*\\)$" line)
                (let* ((hash (match-string 1 line))
                       (author (match-string 2 line))
                       (date (match-string 3 line))
                       (subject (match-string 4 line))
                       (file-at-commit current-file))
                  ;; Look ahead for file status line (may show rename)
                  (let ((j (1+ i)))
                    (while (and (< j (length lines))
                                (not (string-match "^[a-f0-9]+|" (nth j lines))))
                      (let ((status-line (nth j lines)))
                        (cond
                         ;; Rename: R100\told-name\tnew-name
                         ((string-match "^R[0-9]*\t\\(.+\\)\t\\(.+\\)$" status-line)
                          (setq file-at-commit (match-string 1 status-line))
                          (setq current-file (match-string 1 status-line)))
                         ;; Regular change: M\tfilename or A\tfilename etc
                         ((string-match "^[MADC]\t\\(.+\\)$" status-line)
                          (setq file-at-commit (match-string 1 status-line)))))
                      (setq j (1+ j))))
                  (let ((line-start (point)))
                    (insert (propertize hash 'face 'simple-git-commit-hash-face)
                            " "
                            (propertize (format "%-20s" (truncate-string-to-width (or author "") 20))
                                        'face 'simple-git-commit-author-face)
                            " "
                            (propertize (format "%-15s" (truncate-string-to-width (or date "") 15))
                                        'face 'simple-git-commit-date-face)
                            " "
                            (or subject "")
                            "\n")
                    (put-text-property line-start (1- (point)) 'simple-git-commit-hash hash)
                    (put-text-property line-start (1- (point)) 'simple-git-commit-file file-at-commit)
                    (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))))
            (setq i (1+ i))))))
      (goto-char (min pos (point-max))))))

(defun simple-git-file-history-show-diff ()
  "Show diff for file at the commit on current line."
  (interactive)
  (let* ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash))
         (file (get-text-property (line-beginning-position) 'simple-git-commit-file))
         (root simple-git--file-history-root)
         (return-buf (current-buffer)))
    (if (and hash file)
        (let ((buf (get-buffer-create "*simple-git-diff*")))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (call-process "git" nil t nil "show" "--format=" hash "--" file)
              (goto-char (point-min))
              (simple-git-diff-mode)
              (setq simple-git--diff-return-buffer return-buf)))
          (display-buffer buf))
      (message "No commit at point"))))

(defun simple-git-file-history-view-file ()
  "View file as it was at the commit on current line."
  (interactive)
  (let* ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash))
         (file (get-text-property (line-beginning-position) 'simple-git-commit-file))
         (root simple-git--file-history-root))
    (if (and hash file)
        (let* ((buf-name (format "*simple-git:%s@%s*" (file-name-nondirectory file) hash))
               (buf (get-buffer-create buf-name)))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (call-process "git" nil t nil "show" (concat hash ":" file))
              (goto-char (point-min))
              ;; Set mode based on file extension
              (let ((mode (assoc-default file auto-mode-alist 'string-match)))
                (when mode (funcall mode)))
              (setq buffer-read-only t)))
          ;; Display in main window, not side window
          (let ((main-window (or (seq-find (lambda (w)
                                             (not (window-parameter w 'window-side)))
                                           (window-list))
                                 (selected-window))))
            (select-window main-window)
            (switch-to-buffer buf)))
      (message "No commit at point"))))

(defun simple-git-file-history-show-commit ()
  "Show full commit details for the commit on current line."
  (interactive)
  (let* ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash))
         (root simple-git--file-history-root))
    (if hash
        (let ((buf (get-buffer-create "*simple-git-commit-detail*")))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              ;; Get commit info
              (let* ((info (simple-git--run "show" "--no-patch"
                                            "--format=%h%n%an%n%ar%n%s%n%b" hash))
                     (lines (split-string info "\n"))
                     (short-hash (nth 0 lines))
                     (author (nth 1 lines))
                     (date (nth 2 lines))
                     (subject (nth 3 lines))
                     (body (string-trim (mapconcat #'identity (nthcdr 4 lines) "\n"))))
                ;; Header
                (insert (propertize "Commit: " 'face 'simple-git-header-face)
                        (propertize short-hash 'face 'simple-git-commit-hash-face) "\n")
                (insert (propertize "Author: " 'face 'simple-git-header-face)
                        (propertize author 'face 'simple-git-commit-author-face) "\n")
                (insert (propertize "Date:   " 'face 'simple-git-header-face)
                        (propertize date 'face 'simple-git-commit-date-face) "\n\n")
                (insert (propertize subject 'face 'bold) "\n")
                (when (not (string-empty-p body))
                  (insert "\n" body "\n"))
                (insert "\n")
                (insert "Commands: "
                        (propertize "RET" 'face 'font-lock-keyword-face) " show diff  "
                        (propertize "v" 'face 'font-lock-keyword-face) "iew file at this point  "
                        (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
                ;; Get list of changed files
                (let* ((files-output (simple-git--run "show" "--name-status" "--format=" hash))
                       (file-lines (split-string files-output "\n" t)))
                  (insert (propertize "Changed files:\n" 'face 'simple-git-header-face))
                  (dolist (file-line file-lines)
                    (when (string-match "^\\([AMDRT]\\)\t\\(.+\\)$" file-line)
                      (let ((status (match-string 1 file-line))
                            (file (match-string 2 file-line)))
                        (let ((line-start (point)))
                          (insert "  "
                                  (propertize (format "[%s] " status)
                                              'face (pcase status
                                                      ("A" 'simple-git-staged-face)
                                                      ("D" 'simple-git-unstaged-face)
                                                      (_ 'simple-git-untracked-face)))
                                  file "\n")
                          (put-text-property line-start (1- (point)) 'simple-git-commit-file file)
                          (put-text-property line-start (1- (point)) 'simple-git-commit-hash hash)
                          (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))))))))
          (with-current-buffer buf
            (simple-git-commit-detail-mode)
            (goto-char (point-min)))
          (display-buffer buf))
      (message "No commit at point"))))

(defun simple-git-file-history-next-page ()
  "Go to next page of file history."
  (interactive)
  (setq simple-git--file-history-page (1+ simple-git--file-history-page))
  (simple-git-file-history-refresh))

(defun simple-git-file-history-prev-page ()
  "Go to previous page of file history."
  (interactive)
  (when (> simple-git--file-history-page 0)
    (setq simple-git--file-history-page (1- simple-git--file-history-page))
    (simple-git-file-history-refresh)))

(defun simple-git-file-history-first-page ()
  "Go to first page of file history."
  (interactive)
  (setq simple-git--file-history-page 0)
  (simple-git-file-history-refresh))

(defun simple-git-file-history-last-page ()
  "Go to last page of file history."
  (interactive)
  (let ((default-directory simple-git--file-history-root))
    (unless simple-git--file-history-total-commits
      (setq simple-git--file-history-total-commits
            (simple-git--get-file-total-commits simple-git--file-history-file))))
  (setq simple-git--file-history-page
        (max 0 (1- (ceiling (/ (float simple-git--file-history-total-commits) simple-git-log-count)))))
  (simple-git-file-history-refresh))

;;;###autoload
(defun simple-git-file-history ()
  "Show commit history for the current file."
  (interactive)
  (unless (simple-git--in-repo-p)
    (user-error "Not in a Git repository"))
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file"))
  (let* ((root (simple-git--root))
         (file (file-relative-name buffer-file-name root))
         (buf (get-buffer-create (format "*simple-git-history:%s*" (file-name-nondirectory file)))))
    (with-current-buffer buf
      (simple-git-file-history-mode)
      (setq simple-git--file-history-file file)
      (setq simple-git--file-history-root root)
      (setq simple-git--file-history-page 0)
      (simple-git-file-history-refresh))
    (pop-to-buffer buf)))

;;; ============================================================================
;;; Line Blame Mode
;;; ============================================================================

(defvar simple-git-line-blame-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'simple-git-line-blame-show-diff)
    (define-key map (kbd "v") #'simple-git-line-blame-view-file)
    (define-key map (kbd "c") #'simple-git-line-blame-show-commit)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
    (define-key map [mouse-1] #'simple-git-mouse-action)
    map)
  "Keymap for `simple-git-line-blame-mode'.")

(define-derived-mode simple-git-line-blame-mode special-mode "SimpleGit:LineBlame"
  "Major mode for viewing line blame history."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defvar-local simple-git--line-blame-file nil
  "The file being viewed in line blame mode.")

(defvar-local simple-git--line-blame-root nil
  "The git root for line blame mode.")

(defvar-local simple-git--line-blame-line nil
  "The line number being blamed.")

(defun simple-git--get-line-history (file line root)
  "Get history of commits that modified LINE in FILE.
Returns list of (hash author date subject file-at-commit)."
  (let* ((default-directory root)
         (results '())
         (current-file file)
         (current-line line)
         (seen-hashes (make-hash-table :test 'equal))
         (iterations 0)
         (max-iterations 50))
    ;; Iteratively trace the line back through history
    (while (and current-file current-line (< iterations max-iterations))
      (let* ((blame-output (simple-git--run "blame" "-L" (format "%d,%d" current-line current-line)
                                            "--porcelain" "-w" current-file)))
        (if (string-match "^\\([a-f0-9]+\\)" blame-output)
            (let ((hash (match-string 1 blame-output)))
              (if (or (string-prefix-p "00000000" hash)
                      (gethash hash seen-hashes))
                  ;; Uncommitted or already seen - stop
                  (setq current-file nil)
                ;; New commit found
                (puthash hash t seen-hashes)
                (let* ((info (simple-git--run "show" "--no-patch"
                                              "--format=%h|%an|%ar|%s" hash))
                       (parts (split-string (car (split-string info "\n")) "|"))
                       (short-hash (nth 0 parts))
                       (author (nth 1 parts))
                       (date (nth 2 parts))
                       (subject (nth 3 parts)))
                  (push (list short-hash author date subject current-file hash) results))
                ;; Find parent commit and line number
                (let* ((parent-output (simple-git--run "rev-parse" (concat hash "^")))
                       (parent (string-trim parent-output)))
                  (if (or (string-empty-p parent) (string-prefix-p "fatal:" parent))
                      (setq current-file nil)
                    ;; Try to find the line in parent
                    (let ((blame-parent (simple-git--run "blame" "-L" (format "%d,%d" current-line current-line)
                                                         "--porcelain" "-w" parent "--" current-file)))
                      (if (string-match "^\\([a-f0-9]+\\)" blame-parent)
                          ;; Line exists in parent, continue tracing
                          nil
                        ;; Line doesn't exist in parent with same number, stop
                        (setq current-file nil)))))))
          ;; No blame output - stop
          (setq current-file nil)))
      (setq iterations (1+ iterations)))
    (nreverse results)))

(defun simple-git-line-blame-refresh ()
  "Refresh the line blame buffer."
  (let ((inhibit-read-only t)
        (file simple-git--line-blame-file)
        (root simple-git--line-blame-root)
        (line simple-git--line-blame-line))
    (erase-buffer)
    (insert (propertize "Line History (Blame)" 'face 'simple-git-header-face) "\n")
    (insert (propertize "File: " 'face 'simple-git-header-face) file "\n")
    (insert (propertize "Line: " 'face 'simple-git-header-face) (number-to-string line) "\n\n")
    (insert "Commands: "
            (propertize "RET" 'face 'font-lock-keyword-face) " show diff  "
            (propertize "v" 'face 'font-lock-keyword-face) "iew file at this point  "
            (propertize "c" 'face 'font-lock-keyword-face) "ommit view  "
            (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
    (let ((history (simple-git--get-line-history file line root)))
      (if history
          (dolist (entry history)
            (let* ((hash (nth 0 entry))
                   (author (nth 1 entry))
                   (date (nth 2 entry))
                   (subject (nth 3 entry))
                   (file-at-commit (nth 4 entry))
                   (full-hash (nth 5 entry))
                   (line-start (point)))
              (insert (propertize hash 'face 'simple-git-commit-hash-face)
                      " "
                      (propertize (format "%-20s" (truncate-string-to-width (or author "") 20))
                                  'face 'simple-git-commit-author-face)
                      " "
                      (propertize (format "%-15s" (truncate-string-to-width (or date "") 15))
                                  'face 'simple-git-commit-date-face)
                      " "
                      (or subject "")
                      "\n")
              (put-text-property line-start (1- (point)) 'simple-git-commit-hash full-hash)
              (put-text-property line-start (1- (point)) 'simple-git-commit-file file-at-commit)
              (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))
        (insert "  (no history found)\n")))
    (goto-char (point-min))))

(defun simple-git-line-blame-show-diff ()
  "Show diff for commit at point."
  (interactive)
  (let* ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash))
         (file (get-text-property (line-beginning-position) 'simple-git-commit-file))
         (root simple-git--line-blame-root)
         (return-buf (current-buffer)))
    (if (and hash file)
        (let ((buf (get-buffer-create "*simple-git-diff*")))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (call-process "git" nil t nil "show" "--format=" hash "--" file)
              (goto-char (point-min))
              (simple-git-diff-mode)
              (setq simple-git--diff-return-buffer return-buf)))
          (display-buffer buf))
      (message "No commit at point"))))

(defun simple-git-line-blame-view-file ()
  "View file at commit at point."
  (interactive)
  (let* ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash))
         (file (get-text-property (line-beginning-position) 'simple-git-commit-file))
         (root simple-git--line-blame-root))
    (if (and hash file)
        (let* ((buf-name (format "*simple-git:%s@%s*" (file-name-nondirectory file) (substring hash 0 7)))
               (buf (get-buffer-create buf-name)))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (call-process "git" nil t nil "show" (concat hash ":" file))
              (goto-char (point-min))
              (let ((mode (assoc-default file auto-mode-alist 'string-match)))
                (when mode (funcall mode)))
              (setq buffer-read-only t)))
          (let ((main-window (or (seq-find (lambda (w)
                                             (not (window-parameter w 'window-side)))
                                           (window-list))
                                 (selected-window))))
            (select-window main-window)
            (switch-to-buffer buf)))
      (message "No commit at point"))))

(defun simple-git-line-blame-show-commit ()
  "Show full commit details for commit at point."
  (interactive)
  (let* ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash))
         (root simple-git--line-blame-root))
    (if hash
        (let ((buf (get-buffer-create "*simple-git-commit-detail*")))
          (with-current-buffer buf
            (let ((inhibit-read-only t)
                  (default-directory root))
              (erase-buffer)
              (let* ((info (simple-git--run "show" "--no-patch"
                                            "--format=%h%n%an%n%ar%n%s%n%b" hash))
                     (lines (split-string info "\n"))
                     (short-hash (nth 0 lines))
                     (author (nth 1 lines))
                     (date (nth 2 lines))
                     (subject (nth 3 lines))
                     (body (string-trim (mapconcat #'identity (nthcdr 4 lines) "\n"))))
                (insert (propertize "Commit: " 'face 'simple-git-header-face)
                        (propertize short-hash 'face 'simple-git-commit-hash-face) "\n")
                (insert (propertize "Author: " 'face 'simple-git-header-face)
                        (propertize author 'face 'simple-git-commit-author-face) "\n")
                (insert (propertize "Date:   " 'face 'simple-git-header-face)
                        (propertize date 'face 'simple-git-commit-date-face) "\n\n")
                (insert (propertize subject 'face 'bold) "\n")
                (when (not (string-empty-p body))
                  (insert "\n" body "\n"))
                (insert "\n")
                (insert "Commands: "
                        (propertize "RET" 'face 'font-lock-keyword-face) " show diff  "
                        (propertize "v" 'face 'font-lock-keyword-face) "iew file at this point  "
                        (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
                (let* ((files-output (simple-git--run "show" "--name-status" "--format=" hash))
                       (file-lines (split-string files-output "\n" t)))
                  (insert (propertize "Changed files:\n" 'face 'simple-git-header-face))
                  (dolist (file-line file-lines)
                    (when (string-match "^\\([AMDRT]\\)\t\\(.+\\)$" file-line)
                      (let ((status (match-string 1 file-line))
                            (file (match-string 2 file-line)))
                        (let ((line-start (point)))
                          (insert "  "
                                  (propertize (format "[%s] " status)
                                              'face (pcase status
                                                      ("A" 'simple-git-staged-face)
                                                      ("D" 'simple-git-unstaged-face)
                                                      (_ 'simple-git-untracked-face)))
                                  file "\n")
                          (put-text-property line-start (1- (point)) 'simple-git-commit-file file)
                          (put-text-property line-start (1- (point)) 'simple-git-commit-hash hash)
                          (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))))))))
          (with-current-buffer buf
            (simple-git-commit-detail-mode)
            (goto-char (point-min)))
          (display-buffer buf))
      (message "No commit at point"))))

;;;###autoload
(defun simple-git-line-blame ()
  "Show blame history for the current line."
  (interactive)
  (unless (simple-git--in-repo-p)
    (user-error "Not in a Git repository"))
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file"))
  (let* ((root (simple-git--root))
         (file (file-relative-name buffer-file-name root))
         (line (line-number-at-pos))
         (buf (get-buffer-create (format "*simple-git-blame:%s:%d*" (file-name-nondirectory file) line))))
    (with-current-buffer buf
      (simple-git-line-blame-mode)
      (setq simple-git--line-blame-file file)
      (setq simple-git--line-blame-root root)
      (setq simple-git--line-blame-line line)
      (simple-git-line-blame-refresh))
    (pop-to-buffer buf)))

;;; ============================================================================
;;; Branch Graph Mode
;;; ============================================================================

(defvar simple-git-branch-graph-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'simple-git-branch-graph-show-commit)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "g") #'simple-git-branch-graph-refresh)
    (define-key map (kbd "n") #'simple-git-branch-graph-next-page)
    (define-key map (kbd "p") #'simple-git-branch-graph-prev-page)
    (define-key map (kbd "N") #'simple-git-branch-graph-last-page)
    (define-key map (kbd "P") #'simple-git-branch-graph-first-page)
    (define-key map [mouse-1] #'simple-git-mouse-action)
    map)
  "Keymap for `simple-git-branch-graph-mode'.")

(define-derived-mode simple-git-branch-graph-mode special-mode "SimpleGit:Graph"
  "Major mode for viewing branch graph."
  (setq buffer-read-only t)
  (setq truncate-lines t))

(defvar-local simple-git--graph-page 0
  "Current page number in graph view.")

(defvar-local simple-git--graph-total-commits nil
  "Total number of commits in graph.")

(defface simple-git-graph-branch-1
  '((t :foreground "#e06c75"))
  "Face for branch 1 in graph.")

(defface simple-git-graph-branch-2
  '((t :foreground "#98c379"))
  "Face for branch 2 in graph.")

(defface simple-git-graph-branch-3
  '((t :foreground "#61afef"))
  "Face for branch 3 in graph.")

(defface simple-git-graph-branch-4
  '((t :foreground "#c678dd"))
  "Face for branch 4 in graph.")

(defface simple-git-graph-branch-5
  '((t :foreground "#e5c07b"))
  "Face for branch 5 in graph.")

(defface simple-git-graph-branch-6
  '((t :foreground "#56b6c2"))
  "Face for branch 6 in graph.")

(defvar simple-git-branch-graph-count 100
  "Number of commits to show in branch graph.")

(defun simple-git--graph-face-for-column (col)
  "Return face for graph column COL."
  (let ((faces [simple-git-graph-branch-1
                simple-git-graph-branch-2
                simple-git-graph-branch-3
                simple-git-graph-branch-4
                simple-git-graph-branch-5
                simple-git-graph-branch-6]))
    (aref faces (mod col (length faces)))))

(defun simple-git--colorize-graph (graph-str)
  "Apply colors to GRAPH-STR based on column position."
  (let ((result "")
        (col 0)
        (i 0))
    (while (< i (length graph-str))
      (let ((char (aref graph-str i)))
        (cond
         ((memq char '(?* ?| ?/ ?\\))
          (setq result (concat result
                               (propertize (char-to-string char)
                                           'face (simple-git--graph-face-for-column col))))
          (when (memq char '(?* ?|))
            (setq col (1+ col))))
         ((eq char ?\s)
          (setq result (concat result " ")))
         (t
          (setq result (concat result (char-to-string char))))))
      (setq i (1+ i)))
    result))

(defun simple-git--get-all-commits-count ()
  "Get total number of commits across all branches."
  (string-to-number (string-trim (simple-git--run "rev-list" "--count" "--all"))))

(defun simple-git-branch-graph-refresh ()
  "Refresh the branch graph buffer."
  (interactive)
  (when (eq major-mode 'simple-git-branch-graph-mode)
    (let ((inhibit-read-only t)
          (pos (point))
          (default-directory (simple-git--root))
          (skip (* simple-git--graph-page simple-git-branch-graph-count)))
      ;; Get total commits if not cached
      (unless simple-git--graph-total-commits
        (setq simple-git--graph-total-commits (simple-git--get-all-commits-count)))
      (let ((max-page (max 0 (1- (ceiling (/ (float simple-git--graph-total-commits) simple-git-branch-graph-count))))))
        ;; Cap page number
        (when (> simple-git--graph-page max-page)
          (setq simple-git--graph-page max-page)
          (setq skip (* simple-git--graph-page simple-git-branch-graph-count)))
        (erase-buffer)
        (insert (propertize "Branch Graph" 'face 'simple-git-header-face)
                (format " (page %d/%d)" (1+ simple-git--graph-page) (1+ max-page))
                "\n\n")
        (insert "Commands: "
                (propertize "RET" 'face 'font-lock-keyword-face) " show commit  "
                (propertize "n" 'face 'font-lock-keyword-face) "ext page  "
                (propertize "p" 'face 'font-lock-keyword-face) "rev page  "
                (propertize "N" 'face 'font-lock-keyword-face) " last  "
                (propertize "P" 'face 'font-lock-keyword-face) " first  "
                (propertize "g" 'face 'font-lock-keyword-face) " refresh  "
                (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
        ;; Get graph with commit info
        (let* ((output (simple-git--run "log" "--all" "--graph"
                                        (format "--skip=%d" skip)
                                        (format "-n%d" simple-git-branch-graph-count)
                                        "--pretty=format:%h|%an|%ar|%s|%d"))
               (lines (split-string output "\n")))
        (dolist (line lines)
          (if (string-match "^\\([*| /\\\\]+\\)\\([a-f0-9]+\\)|\\([^|]*\\)|\\([^|]*\\)|\\([^|]*\\)|\\(.*\\)$" line)
              ;; Line with commit info
              (let* ((graph (match-string 1 line))
                     (hash (match-string 2 line))
                     (author (match-string 3 line))
                     (date (match-string 4 line))
                     (subject (match-string 5 line))
                     (refs (match-string 6 line))
                     (line-start (point)))
                (insert (simple-git--colorize-graph graph))
                (insert (propertize hash 'face 'simple-git-commit-hash-face) " ")
                ;; Show branch/tag refs if present
                (when (and refs (not (string-empty-p (string-trim refs))))
                  (insert (propertize (string-trim refs) 'face 'font-lock-keyword-face) " "))
                (insert (propertize (truncate-string-to-width (or author "") 15)
                                    'face 'simple-git-commit-author-face) " ")
                (insert (or subject "") "\n")
                (put-text-property line-start (1- (point)) 'simple-git-commit-hash hash)
                (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face))
            ;; Graph-only line (no commit)
            (when (string-match "^\\([*| /\\\\]+\\)$" line)
              (insert (simple-git--colorize-graph (match-string 1 line)) "\n"))))))
      (goto-char (min pos (point-max))))))

(defun simple-git-branch-graph-next-page ()
  "Go to next page of graph."
  (interactive)
  (setq simple-git--graph-page (1+ simple-git--graph-page))
  (simple-git-branch-graph-refresh))

(defun simple-git-branch-graph-prev-page ()
  "Go to previous page of graph."
  (interactive)
  (when (> simple-git--graph-page 0)
    (setq simple-git--graph-page (1- simple-git--graph-page))
    (simple-git-branch-graph-refresh)))

(defun simple-git-branch-graph-first-page ()
  "Go to first page of graph."
  (interactive)
  (setq simple-git--graph-page 0)
  (simple-git-branch-graph-refresh))

(defun simple-git-branch-graph-last-page ()
  "Go to last page of graph."
  (interactive)
  (unless simple-git--graph-total-commits
    (setq simple-git--graph-total-commits (simple-git--get-all-commits-count)))
  (setq simple-git--graph-page
        (max 0 (1- (ceiling (/ (float simple-git--graph-total-commits) simple-git-branch-graph-count)))))
  (simple-git-branch-graph-refresh))

(defun simple-git-branch-graph-show-commit ()
  "Show commit details for commit at point."
  (interactive)
  (when-let ((hash (get-text-property (line-beginning-position) 'simple-git-commit-hash)))
    (let ((buf (get-buffer-create "*simple-git-commit-detail*"))
          (root (simple-git--root)))
      (with-current-buffer buf
        (let ((inhibit-read-only t)
              (default-directory root))
          (erase-buffer)
          ;; Get commit info
          (let* ((info (simple-git--run "show" "--no-patch"
                                        "--format=%h%n%an%n%ar%n%s%n%b" hash))
                 (lines (split-string info "\n"))
                 (short-hash (nth 0 lines))
                 (author (nth 1 lines))
                 (date (nth 2 lines))
                 (subject (nth 3 lines))
                 (body (string-trim (mapconcat #'identity (nthcdr 4 lines) "\n"))))
            ;; Header
            (insert (propertize "Commit: " 'face 'simple-git-header-face)
                    (propertize short-hash 'face 'simple-git-commit-hash-face) "\n")
            (insert (propertize "Author: " 'face 'simple-git-header-face)
                    (propertize author 'face 'simple-git-commit-author-face) "\n")
            (insert (propertize "Date:   " 'face 'simple-git-header-face)
                    (propertize date 'face 'simple-git-commit-date-face) "\n\n")
            (insert (propertize subject 'face 'bold) "\n")
            (when (not (string-empty-p body))
              (insert "\n" body "\n"))
            (insert "\n")
            (insert "Commands: "
                    (propertize "RET" 'face 'font-lock-keyword-face) " show diff  "
                    (propertize "v" 'face 'font-lock-keyword-face) "iew file at this point  "
                    (propertize "q" 'face 'font-lock-keyword-face) "uit\n\n")
            ;; Get list of changed files
            (let* ((files-output (simple-git--run "show" "--name-status" "--format=" hash))
                   (file-lines (split-string files-output "\n" t)))
              (insert (propertize "Changed files:\n" 'face 'simple-git-header-face))
              (dolist (file-line file-lines)
                (when (string-match "^\\([AMDRT]\\)\t\\(.+\\)$" file-line)
                  (let ((status (match-string 1 file-line))
                        (file (match-string 2 file-line)))
                    (let ((line-start (point)))
                      (insert "  "
                              (propertize (format "[%s] " status)
                                          'face (pcase status
                                                  ("A" 'simple-git-staged-face)
                                                  ("D" 'simple-git-unstaged-face)
                                                  (_ 'simple-git-untracked-face)))
                              file "\n")
                      (put-text-property line-start (1- (point)) 'simple-git-commit-file file)
                      (put-text-property line-start (1- (point)) 'simple-git-commit-hash hash)
                      (put-text-property line-start (1- (point)) 'mouse-face 'simple-git-highlight-face)))))))))
      (with-current-buffer buf
        (simple-git-commit-detail-mode)
        (goto-char (point-min)))
      (display-buffer buf))))

;;;###autoload
(defun simple-git-branch-graph ()
  "Show branch graph visualization."
  (interactive)
  (unless (simple-git--in-repo-p)
    (user-error "Not in a Git repository"))
  (let ((buf (get-buffer-create "*simple-git-graph*")))
    (with-current-buffer buf
      (simple-git-branch-graph-mode)
      (simple-git-branch-graph-refresh))
    (pop-to-buffer buf)))

;;; ============================================================================
;;; Entry Point
;;; ============================================================================

;;;###autoload
(defun simple-git-status ()
  "Show Git status."
  (interactive)
  (unless (simple-git--in-repo-p)
    (user-error "Not in a Git repository"))
  (let ((buf (get-buffer-create "*simple-git-status*")))
    (with-current-buffer buf
      (simple-git-status-mode)
      (simple-git-status-refresh))
    (pop-to-buffer buf)))

;;;###autoload
(defun simple-git ()
  "Open simple-git status buffer."
  (interactive)
  (simple-git-status))

(provide 'simple-git)
;;; simple-git.el ends here
