;; Max's init.el  -*- lexical-binding: t; -*-

;; General Configuration

;; set load paths for lisp evaluation
(add-to-list 'load-path "~/.emacs.d/lisp/")

(let ((default-directory "~/.emacs.d/lisp/"))
  (normal-top-level-add-subdirs-to-load-path))

  (setq indent-tabs-mode t)
  (stupid-indent-mode)
  (setq-local stupid-indent-level 4)
))

;; general settings
(setq-default inhibit-startup-screen t)
(show-paren-mode 1)
(delete-selection-mode 1)
(setq cua-auto-tabify-rectangles nil) ;; Don't tabify after rectangle commands
(transient-mark-mode 1) ;; No region when it is not highlighted
(setq cua-keep-region-after-copy nil) ;; don't reselect after copy
(menu-bar-mode -1)
(scroll-bar-mode -1)
(tool-bar-mode -1)
(global-auto-revert-mode t)
(electric-pair-mode -1)
(setq ns-pop-up-frames nil)
(setq initial-major-mode 'text-mode)
(setq initial-scratch-message "Just give him some food, water, and a funny hat." )
(setq ediff-split-window-function 'split-window-horizontally)
(setq-default truncate-lines 1)
(setq column-number-mode t)
(setq dired-dnd-protocol-alist nil)
(global-so-long-mode 1)
(column-number-mode 1)
(blink-cursor-mode 0)
(setq use-dialog-box nil)
(electric-indent-mode 0)
(tooltip-mode -1)
(setq-default select-enable-clipboard nil)
(setq-default x-select-enable-clipboard nil)
(setq-default backward-delete-char-untabify-method nil)
(setq ring-bell-function 'ignore)
(setq custom-file "~/.emacs.d/custom.el") ;; place custom in a separate file
(setq-default require-final-newline t)
(cua-mode t)

;; backup and autosave settings
(setq backup-by-copying t      ; don't clobber symlinks
      backup-directory-alist '(("." . "~/.emacs.d/saves/"))    ; don't litter my fs tree
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t)       ; use versioned backups
(setq auto-save-file-name-transforms
      `((".*" "~/.emacs.d/saves/" t)))
(setq create-lockfiles nil)

;; Keybindings / Keybinds
;; global
(global-set-key (kbd "S-<down-mouse-1>") #'my-mouse-start-rectangle)
(global-set-key (kbd "<f5>") 'revert-buffer-quick)
(global-set-key (kbd "<f6>") 'my-file-manager-command)
(global-set-key (kbd "<C-f6>") 'my-terminal-emulator-command)
(global-set-key [f8] 'goto-line)
(global-set-key (kbd "C-\\") 'my-transpose-windows)
(global-unset-key (kbd "C-x C-SPC"))
(global-set-key (kbd "C-x C-SPC") 'rectangle-mark-mode)
(global-set-key [C-return] 'save-buffer)
(global-set-key [?\C-z] 'undo)
(global-set-key (kbd "C-*") 'search-current-word)
(global-set-key (kbd "C-;") 'comment-line)
(global-set-key (kbd "M-<f4>") 'save-buffers-kill-terminal) ;; windows thing
(global-set-key (kbd "C-y") 'clipboard-yank) ;; fix killring messing with system clipboard
(global-set-key (kbd "C-w") 'clipboard-kill-region)
(global-set-key (kbd "M-w") 'clipboard-kill-ring-save)
(global-set-key (kbd "M-j") 'my-duplicate-line)
(global-set-key (kbd "<f9>") 'bookmark-jump)
(global-set-key (kbd "<f10>") 'bookmark-set)
(global-set-key (kbd "<f11>") 'bookmark-delete)

;; custom bind minor mode
;; this allows binding keys that override all other modes
(defvar my-keys-minor-mode-map
  (let ((map (make-sparse-keymap)))
  (define-key map (kbd "M-p") 'backward-paragraph)
  (define-key map (kbd "M-n") 'forward-paragraph)
  (define-key map (kbd "C-o") 'next-multiframe-window)
  (define-key map [?\C-0] 'delete-window)
  (define-key map [?\C-1] 'delete-other-windows)
  (define-key map [?\C-2] 'split-window-vertically)
  (define-key map [?\C-3] 'split-window-horizontally)
  (define-key map [?\C-4] 'find-file-at-point)
  (define-key map [?\C-5] 'switch-to-buffer)
  (define-key map (kbd "C-j") 'dabbrev-expand)
    map)
  "my-keys-minor-mode keymap.")

(define-minor-mode my-keys-minor-mode
  "A minor mode so that my key settings override annoying major modes."
  :init-value t
  :lighter "")

;; don't enable override keymap in minibuf
(defun my-minibuffer-setup-hook ()
 (my-keys-minor-mode 0))
(add-hook 'minibuffer-setup-hook 'my-minibuffer-setup-hook)

(my-keys-minor-mode 1)

;; Custom Functions

;; test function
(defun my-test ()
  (interactive)
  (message "Hello world!"))

;; duplicate line (cleanly)
;; https://stackoverflow.com/questions/88399/how-do-i-duplicate-a-whole-line-in-emacs
(defun my-duplicate-line (arg)
  "Duplicate current line, leaving point in lower line."
  (interactive "*p")
  (setq buffer-undo-list (cons (point) buffer-undo-list))
  (let ((bol (save-excursion (beginning-of-line) (point)))
	eol)
    (save-excursion
      (end-of-line)
      (setq eol (point))
      (let ((line (buffer-substring bol eol))
	    (buffer-undo-list t)
	    (count arg))
	(while (> count 0)
	  (newline)
	  (insert line)
	  (setq count (1- count)))
	)
      (setq buffer-undo-list (cons (cons eol (point)) buffer-undo-list)))
    )
  (next-line arg))

;; select rectangle with shift+mouse
(defun my-mouse-start-rectangle (start-event)
  (interactive "e")
  (deactivate-mark)
  (mouse-set-point start-event)
  (rectangle-mark-mode +1)
  (let ((drag-event))
    (track-mouse
      (while (progn
	       (setq drag-event (read-event))
	       (mouse-movement-p drag-event))
	(mouse-set-point drag-event)))))

;; open file manager
(defun my-file-manager-command ()
  (interactive)
  (cond ((eq system-type 'windows-nt)
     (shell-command "explorer.exe ."))
    ((eq system-type 'gnu/linux)
     (shell-command "setsid -f nautilus . >/dev/null 2>&1"))))

;; open terminal or cmd prompt
(defun my-terminal-emulator-command ()
  (interactive)
  (cond ((eq system-type 'windows-nt)
     (let ((proc (start-process "cmd" nil "cmd.exe" "/C" "start" "cmd.exe")))
       (set-process-query-on-exit-flag proc nil)))
    ((eq system-type 'gnu/linux)
     (shell-command "setsid -f gnome-terminal . >/dev/null 2>&1"))))

;; transpose (move) windows
(defun my-transpose-windows (arg)
  "Transpose the buffers shown in two windows."
   (interactive "p")
   (let ((selector (if (>= arg 0) 'next-window 'previous-window)))
     (while (/= arg 0)
       (let ((this-win (window-buffer))
	     (next-win (window-buffer (funcall selector))))
	 (set-window-buffer (selected-window) next-win)
	 (set-window-buffer (funcall selector) this-win)
	 (select-window (funcall selector)))
       (setq arg (if (plusp arg) (1- arg) (1+ arg))))))

;; search current word
(defun search-current-word ()
  (interactive)
  (let ($p1 $p2)
    (if (region-active-p)
	(setq $p1 (region-beginning) $p2 (region-end))
      (save-excursion

	(skip-chars-backward "-_A-Za-z0-9")
	(setq $p1 (point))
	(right-char)
	(skip-chars-forward "-_A-Za-z0-9")
	(setq $p2 (point))))
    (setq mark-active nil)
    (when (< $p1 (point))
      (goto-char $p1))
    (isearch-mode t)
    (isearch-yank-string (buffer-substring-no-properties $p1 $p2))))

;; Tweaks / Fixes
;; Emacs sucks by default, here are some fixes.

;; fix isearch
(defadvice isearch-search (after isearch-no-fail activate)
  (unless isearch-success
    (ad-disable-advice 'isearch-search 'after 'isearch-no-fail)
    (ad-activate 'isearch-search)
    (isearch-repeat (if isearch-forward 'forward))
    (ad-enable-advice 'isearch-search 'after 'isearch-no-fail)
    (ad-activate 'isearch-search)))

(add-hook 'isearch-mode-end-hook
	  #'endless/goto-match-beginning)

(defun endless/goto-match-beginning ()
  "Go to the start of current isearch match.
Use in `isearch-mode-end-hook'."
  (when (and isearch-forward
	     (number-or-marker-p isearch-other-end)
	     (not mark-active)
	     (not isearch-mode-end-hook-quit))
    (goto-char isearch-other-end)))

;; appearance
;; (set-face-attribute 'default nil :font "Consolas-15")

;; the name of my emacs color scheme
(custom-set-faces
 '(default ((t (:foreground "#d3b58d" :background "#181E2C"))))
 '(custom-group-tag-face ((t (:underline t :foreground "lightblue"))) t)
 '(custom-variable-tag-face ((t (:underline t :foreground "lightblue"))) t)
 '(font-lock-builtin-face ((t nil)))
 '(font-lock-comment-face ((t (:foreground "#bf9319"))))
 '(font-lock-function-name-face ((((class color) (background dark)) (:foreground "white"))))
 '(font-lock-keyword-face ((t (:foreground "white" ))))
 '(font-lock-string-face ((t (:foreground "#8fcddb"))))
 '(font-lock-variable-name-face ((((class color) (background dark)) (:foreground "#c8d4ec"))))
 '(font-lock-warning-face ((t (:foreground "#504038"))))
 '(highlight ((t (:foreground "navyblue" :background "darkseagreen2"))))
 '(mode-line ((t (:inverse-video t))))
 '(region ((t (:background "blue"))))
 '(widget-field-face ((t (:foreground "white"))) t)
 '(widget-single-line-field-face ((t (:background "darkgray"))) t))

(set-background-color "#181E2C")
(global-font-lock-mode 1)
(set-cursor-color "lightgreen")
