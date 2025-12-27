;; Max's init.el  -*- lexical-binding: t; -*-

;;; ============================================================================
;;; PACKAGE LOADING & LOAD PATHS
;;; ============================================================================

(add-to-list 'load-path "~/.emacs.d/lisp/")

(let ((default-directory "~/.emacs.d/lisp/"))
  (normal-top-level-add-subdirs-to-load-path))

;; Core libraries
(require 's)
(require 'dash)
(require 'popup)

;; Completion framework
(require 'ivy)
(require 'counsel)

;; Language modes
(require 'yaml-mode)
(require 'dockerfile-mode)
(require 'go-mode)
(require 'jai-mode)
(require 'simpc-mode)
(require 'web-mode)

;; Editing enhancements
(require 'stupid-indent-mode)
(require 'multiple-cursors)
(require 'vundo)

;; Navigation
(require 'dumb-jump)
(require 'eglot)

;; Search
(require 'xah-find)

;;; ============================================================================
;;; MODE ASSOCIATIONS
;;; ============================================================================

(add-to-list 'auto-mode-alist '("\\.yml\\'" . yaml-mode))
(add-to-list 'auto-mode-alist '("\\.go\\'" . go-mode))
(add-to-list 'auto-mode-alist '("\\.jai\\'" . jai-mode))
(add-to-list 'auto-mode-alist '("\\.css\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.js\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.html\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.\\(as\\(px?\\|cx\\)\\|razor\\|blazor\\|cshtml\\)\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.[hc]\\(pp\\)?\\'" . simpc-mode))

;;; ============================================================================
;;; IVY & COMPLETION FRAMEWORK
;;; ============================================================================

(ivy-mode 1)
(setq ivy-use-virtual-buffers t)
(setq ivy-count-format "(%d/%d) ")
(setq ivy-wrap t)

;;; ============================================================================
;;; XREF, CTAGS & NAVIGATION
;;; ============================================================================

;; dumb-jump as fallback for xref
(setq dumb-jump-force-searcher 'grep)
(setq dumb-jump-selector 'ivy)
(setq xref-show-definitions-function #'xref-show-definitions-completing-read)
(setq tags-revert-without-query t)
(add-hook 'xref-backend-functions #'dumb-jump-xref-activate 100)

;;; ============================================================================
;;; EGLOT (LSP) CONFIGURATION
;;; ============================================================================

;; When eglot is active, xref commands (F12, M-f12) automatically use LSP
;; instead of CTAGS. Eglot registers itself as a higher-priority xref backend.

(setq eglot-autoshutdown t)  ; shutdown server when last buffer is closed
(setq eglot-confirm-server-initiated-edits nil)  ; don't ask for confirmation on renames

;; disable LSP visual indicators but keep diagnostics available
(add-to-list 'eglot-ignored-server-capabilities :documentHighlightProvider)

;; Go: auto-start eglot (requires gopls: go install golang.org/x/tools/gopls@latest)
(add-hook 'go-mode-hook 'eglot-ensure)

;; auto-confirm "modified buffer" prompts when jumping from diagnostics
(defun my-auto-confirm-modified-buffer (orig-fun prompt)
  "Auto-confirm prompts about modified buffers having wrong location."
  (if (string-match-p "has been modified.*wrong location" prompt)
      t
    (funcall orig-fun prompt)))
(advice-add 'y-or-n-p :around #'my-auto-confirm-modified-buffer)

(defun my-lsp-find-workspace-symbol ()
  "Interactively search for symbols in workspace using LSP."
  (interactive)
  (if (eglot-managed-p)
      (let ((server (eglot-current-server))
            (root (project-root (project-current))))
        (ivy-read "Symbol: "
                  (lambda (input)
                    (when (and input (>= (length input) 1))
                      (condition-case nil
                          (let* ((resp (jsonrpc-request server :workspace/symbol
                                                        `(:query ,input)))
                                 (items (append resp nil)))
                            (delq nil
                                  (mapcar (lambda (item)
                                            (condition-case nil
                                                (let* ((name (plist-get item :name))
                                                       (loc (plist-get item :location))
                                                       (uri (plist-get loc :uri))
                                                       (range (plist-get loc :range))
                                                       (start (plist-get range :start))
                                                       (line (1+ (plist-get start :line)))
                                                       (file (eglot-uri-to-path uri))
                                                       (rel-path (file-relative-name file root)))
                                                  (propertize (format "%s  %s:%d" name rel-path line)
                                                              'file file
                                                              'line line))
                                              (error nil)))
                                          items)))
                        (error nil))))
                  :dynamic-collection t
                  :require-match t
                  :action (lambda (candidate)
                            (when (and candidate (get-text-property 0 'file candidate))
                              (find-file (get-text-property 0 'file candidate))
                              (goto-char (point-min))
                              (forward-line (1- (get-text-property 0 'line candidate)))))))
    (call-interactively 'xref-find-apropos)))

;;; ============================================================================
;;; FLYMAKE & DIAGNOSTICS
;;; ============================================================================

;; hide squiggly underlines
(set-face-attribute 'flymake-error nil :underline nil)
(set-face-attribute 'flymake-warning nil :underline nil)
(set-face-attribute 'flymake-note nil :underline nil)

;; hide fringe indicators
(setq flymake-fringe-indicator-position nil)

(defun my-flymake-show-project-errors-warnings ()
  "Show project diagnostics, filtering out notes (only errors and warnings)."
  (interactive)
  ;; Kill existing diagnostics buffer to force refresh
  (when-let ((buf (get-buffer "*Flymake diagnostics*")))
    (kill-buffer buf))
  ;; Refresh flymake on all project buffers
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (bound-and-true-p flymake-mode)
                 (buffer-file-name))
        (flymake-start))))
  (flymake-show-project-diagnostics)
  (run-at-time 0.1 nil
               (lambda ()
                 (when-let ((buf (get-buffer "*Flymake diagnostics*")))
                   (with-current-buffer buf
                     (let ((inhibit-read-only t))
                       (goto-char (point-min))
                       (while (not (eobp))
                         (if (looking-at ".*\\bnote\\b.*$")
                             (delete-region (line-beginning-position) (1+ (line-end-position)))
                           (forward-line 1)))))))))

;;; ============================================================================
;;; MULTIPLE CURSORS
;;; ============================================================================

(setq mc/always-run-for-all t)
(setq mc/cycle-looping-behaviour 'continue)
(define-key mc/keymap (kbd "<escape>") 'mc/keyboard-quit)
(define-key mc/keymap (kbd "<return>") nil)

(advice-add 'mc/load-lists :after
            (lambda () (add-to-list 'mc/cmds-to-run-once 'my-mc-mark-next-like-this)))


;;; ============================================================================
;;; INDENTATION SETTINGS
;;; ============================================================================

;; default indentation
(setq-default indent-tabs-mode t)
(setq-default tab-width 4)
(setq-default stupid-indent-level 4)
(add-hook 'text-mode-hook 'stupid-indent-mode)
(add-hook 'prog-mode-hook 'stupid-indent-mode)

;; per-language indentation (indent-tabs-mode: t = tabs, nil = spaces)
(add-hook 'go-mode-hook (lambda ()
                          (setq-local indent-tabs-mode t)
                          (setq-local tab-width 4)
                          (setq-local stupid-indent-level 4)))

(add-hook 'jai-mode-hook (lambda ()
                           (setq-local indent-tabs-mode nil)
                           (setq-local tab-width 4)
                           (setq-local stupid-indent-level 4)))

(add-hook 'simpc-mode-hook (lambda ()
                           (setq-local indent-tabs-mode t)
                           (setq-local tab-width 4)
                           (setq-local stupid-indent-level 4)))

(add-hook 'python-mode-hook (lambda ()
                              (setq-local indent-tabs-mode nil)
                              (setq-local tab-width 4)
                              (setq-local stupid-indent-level 4)))

(add-hook 'js-mode-hook (lambda ()
                          (setq-local indent-tabs-mode nil)
                          (setq-local tab-width 4)
                          (setq-local stupid-indent-level 4)))

(add-hook 'emacs-lisp-mode-hook (lambda ()
                                  (setq-local indent-tabs-mode nil)
                                  (setq-local tab-width 2)
                                  (setq-local stupid-indent-level 2)))

;;; ============================================================================
;;; GENERAL SETTINGS & UI
;;; ============================================================================

;; startup
(setq-default inhibit-startup-screen t)
(setq initial-major-mode 'text-mode)
(setq initial-scratch-message "Just give him some food, water, and a funny hat." )

;; frame & window
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(setq ns-pop-up-frames nil)
(setq use-dialog-box nil)
(setq frame-inhibit-implied-resize t)

;; UI chrome
(menu-bar-mode -1)
(scroll-bar-mode -1)
(tool-bar-mode -1)
(context-menu-mode -1)
(tooltip-mode -1)
(blink-cursor-mode 0)

;; editing behavior
(show-paren-mode 1)
(delete-selection-mode 1)
(cua-mode t)
(setq cua-auto-tabify-rectangles nil)
(setq cua-keep-region-after-copy nil)
(transient-mark-mode 1)
(electric-pair-mode -1)
(electric-indent-mode 0)
(global-auto-revert-mode t)
(global-so-long-mode 1)
(global-hl-line-mode -1)

;; display
(setq-default truncate-lines 1)
(setq column-number-mode t)
(column-number-mode 1)
(global-font-lock-mode 1)

;; clipboard
(setq-default select-enable-clipboard t)
(setq-default x-select-enable-clipboard t)

;; misc behavior
(setq-default backward-delete-char-untabify-method nil)
(setq ring-bell-function 'ignore)
(setq-default require-final-newline t)
(setq ediff-split-window-function 'split-window-horizontally)
(setq dired-dnd-protocol-alist nil)
(setq custom-file "~/.emacs.d/custom.el")

;; mouse - disable right-click context menu
(global-set-key [mouse-3] 'ignore)
(global-set-key [down-mouse-3] 'ignore)
(global-set-key [C-down-mouse-1] 'ignore)
(global-set-key [C-down-mouse-3] 'ignore)

;; dired: mouse click opens in same window
(add-hook 'dired-mode-hook
          (lambda ()
            (define-key dired-mode-map [mouse-2] 'dired-find-file)))

;;; ============================================================================
;;; BOTTOM PANEL / COMPILATION WINDOW
;;; ============================================================================

(setq compilation-scroll-output -1)
(setq compilation-save-buffers-predicate 'ignore)

(defvar my-bottom-panel-buffers '("\\*compilation\\*" "\\*xref\\*" "\\*Flymake diagnostics.*\\*")
  "List of buffer name patterns for bottom panel.")

(defun my-bottom-panel-buffer-p (buf)
  "Check if BUF is a bottom panel buffer."
  (seq-some (lambda (pat) (string-match-p pat (buffer-name buf)))
            my-bottom-panel-buffers))

(defun my-get-bottom-panel-window ()
  "Get existing bottom panel window if any."
  (seq-find (lambda (w)
              (and (window-at-side-p w 'bottom)
                   (my-bottom-panel-buffer-p (window-buffer w))))
            (window-list)))

(defun my-display-in-bottom-panel (buffer alist)
  "Display BUFFER in bottom panel, reusing existing panel window."
  (let ((window (my-get-bottom-panel-window)))
    (if window
        (progn
          (set-window-buffer window buffer)
          window)
      (let ((new-window (display-buffer-at-bottom buffer alist)))
        (when new-window
          (with-selected-window new-window
            (set-window-parameter new-window 'window-height 0.25)))
        new-window))))

(add-to-list 'display-buffer-alist
             '("\\*compilation\\*" (my-display-in-bottom-panel) (window-height . 0.25)))
(add-to-list 'display-buffer-alist
             '("\\*xref\\*" (my-display-in-bottom-panel) (window-height . 0.25)))
(add-to-list 'display-buffer-alist
             '("\\*Flymake diagnostics.*\\*" (my-display-in-bottom-panel) (window-height . 0.25)))

(defun my-bottom-panel-toggle ()
  "Toggle the bottom panel. Close if visible, open if hidden."
  (interactive)
  (let ((panel-window (my-get-bottom-panel-window)))
    (if panel-window
        (delete-window panel-window)
      (let ((matching-buffers (seq-filter
                               (lambda (buf)
                                 (seq-some (lambda (pat) (string-match-p pat (buffer-name buf)))
                                           my-bottom-panel-buffers))
                               (buffer-list))))
        (if matching-buffers
            (my-display-in-bottom-panel (car matching-buffers) '((window-height . 0.25)))
          (message "No bottom panel buffers open."))))))

;;; ============================================================================
;;; BACKUP & AUTOSAVE SETTINGS
;;; ============================================================================

(setq backup-by-copying t
      backup-directory-alist '(("." . "~/.emacs.d/saves/"))
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t)

(setq auto-save-file-name-transforms
      `((".*" "~/.emacs.d/saves/" t)))

(setq create-lockfiles nil)

;;; ============================================================================
;;; PROCESS MANAGEMENT
;;; ============================================================================

(defun my-kill-process-tree (pid)
  "Kill PID and all its descendant processes."
  (let ((children (split-string
                   (shell-command-to-string
                    (format "pgrep -P %d 2>/dev/null" pid))
                   "\n" t)))
    (dolist (child children)
      (when (string-match "^[0-9]+$" child)
        (my-kill-process-tree (string-to-number child)))))
  (ignore-errors (call-process "kill" nil nil nil "-9" (number-to-string pid))))

;; Ensure all subprocesses are killed when Emacs exits
(add-hook 'kill-emacs-hook
          (lambda ()
            (dolist (proc (process-list))
              (when (process-live-p proc)
                (let ((pid (process-id proc)))
                  (when pid
                    (my-kill-process-tree pid)))
                (set-process-query-on-exit-flag proc t)
                (ignore-errors (delete-process proc))))))

;; Kill terminal buffer when process exits
(defun my-term-handle-exit (&optional process-name msg)
  "Kill terminal buffer when process exits."
  (when (buffer-live-p (current-buffer))
    (kill-buffer (current-buffer))))

(advice-add 'term-handle-exit :after #'my-term-handle-exit)

;;; ============================================================================
;;; KEYBINDINGS
;;; ============================================================================

;; Mac-specific modifier keys
(setq mac-command-modifier 'control)
(setq mac-control-modifier 'command)

;; isearch settings
(setq isearch-wrap-pause 'no)

;; --- File & Buffer Operations ---
(global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "C-n") (lambda () (interactive) (switch-to-buffer (generate-new-buffer "untitled"))))
(global-set-key (kbd "C-p") 'project-find-file)
(global-set-key (kbd "C-3") 'switch-to-buffer)
(global-set-key (kbd "C-4") 'find-file)
(global-set-key (kbd "C-q") 'save-buffers-kill-terminal)
(global-set-key (kbd "M-<f4>") 'save-buffers-kill-terminal)

;; --- Window & Pane Management ---
(global-set-key (kbd "C-w") 'delete-window)
(global-set-key (kbd "C-\\") 'split-window-below)
(global-set-key (kbd "C-|") 'split-window-right)
(global-set-key (kbd "C-o") 'next-multiframe-window)
(global-set-key (kbd "C-1") 'my-select-left-pane)
(global-set-key (kbd "C-2") 'my-select-right-pane)
(global-set-key (kbd "<f11>") 'toggle-frame-maximized)

;; --- Selection & Editing ---
(global-set-key (kbd "C-a") 'mark-whole-buffer)
(global-set-key (kbd "C-l") 'my-select-line)
(global-set-key (kbd "C-/") 'my-toggle-comment)
(global-set-key (kbd "M-j") 'my-duplicate-line)
(global-unset-key (kbd "C-x C-SPC"))
(global-set-key (kbd "C-x C-SPC") 'rectangle-mark-mode)
(global-set-key (kbd "S-<down-mouse-1>") #'my-mouse-start-rectangle)

;; --- Clipboard & Kill Ring ---
(global-set-key [?\C-z] 'undo)
(global-set-key (kbd "C-y") 'clipboard-yank)
(global-set-key (kbd "M-w") 'clipboard-kill-ring-save)

;; --- Navigation ---
(global-set-key (kbd "<home>") 'my-smart-home)
(global-set-key (kbd "<end>") 'move-end-of-line)
(global-set-key (kbd "M-p") 'backward-paragraph)
(global-set-key (kbd "M-n") 'forward-paragraph)
(global-set-key [f8] 'goto-line)
(when (eq system-type 'darwin)
  (global-set-key (kbd "C-<left>") 'my-smart-home)
  (global-set-key (kbd "C-<right>") 'move-end-of-line))

;; --- Line Movement ---
(global-set-key (kbd "M-<up>") 'my-move-line-up)
(global-set-key (kbd "M-<down>") 'my-move-line-down)

;; --- Search & Replace ---
(global-set-key (kbd "C-f") 'my-isearch-forward)
(global-set-key (kbd "C-*") 'search-current-word)
(global-set-key (kbd "C-S-f") 'my-project-find-text)
(global-set-key (kbd "C-S-h") 'my-find-replace)

;; --- Code Navigation (xref/LSP) ---
(global-set-key (kbd "<f12>") 'my-xref-find-definitions-same-pane)
(global-set-key (kbd "C-<f12>") 'xref-find-references)
(global-set-key (kbd "C-{") 'xref-go-back)
(global-set-key (kbd "C-}") 'xref-go-forward)
(global-set-key (kbd "<mouse-3>") 'xref-go-back)
(global-set-key (kbd "<mouse-4>") 'xref-go-forward)
(global-set-key (kbd "C-<mouse-1>") 'my-xref-find-definitions-at-click)
(global-set-key (kbd "C-S-<mouse-1>") 'my-xref-find-references-at-click)
(global-set-key (kbd "C-t") 'my-lsp-find-workspace-symbol)

;; --- LSP / Eglot ---
(global-set-key (kbd "<f2>") 'eglot-rename)
(global-set-key (kbd "<S-f2>") 'eglot-reconnect)
(global-set-key (kbd "C-S-m") 'my-flymake-show-project-errors-warnings)

;; --- Compilation & Build ---
(global-set-key (kbd "<f1>") 'my-bottom-panel-toggle)
(global-set-key (kbd "<f5>") 'my-compile-last)
(global-set-key (kbd "<C-S-f5>") 'my-compile-custom)

;; --- External Tools ---
(global-set-key (kbd "<f6>") 'my-file-manager-command)
(global-set-key (kbd "<C-f6>") 'my-terminal-emulator-command)

;; --- Project Management ---
(global-set-key (kbd "<f7>") 'project-switch-project)
(global-set-key (kbd "C-S-p") 'counsel-M-x)

;; --- Bookmarks ---
(global-set-key (kbd "<f9>") 'bookmark-jump)
(global-set-key (kbd "<f10>") 'bookmark-set)

;; --- Themes ---
(global-set-key (kbd "<f3>") 'my-select-theme)

;; --- Zoom ---
(global-set-key (kbd "C-=") 'my-global-zoom-in)
(global-set-key (kbd "C--") 'my-global-zoom-out)
(global-set-key (kbd "C-0") 'my-global-zoom-reset)
(global-unset-key (kbd "C-x C-="))
(global-unset-key (kbd "C-x C--"))
(global-unset-key (kbd "C-x C-0"))
(global-set-key (kbd "C-<wheel-up>") 'ignore)
(global-set-key (kbd "C-<wheel-down>") 'ignore)

;; --- Completion (dabbrev) ---
(global-set-key (kbd "C-j") 'dabbrev-expand)

;; --- Multiple Cursors ---
(global-set-key (kbd "C-d") 'my-mc-mark-next-like-this)
(global-set-key (kbd "C-S-d") 'mc/mark-previous-like-this-word)
(global-set-key (kbd "C-S-a") 'mc/mark-all-like-this)
(global-set-key (kbd "M-<down-mouse-1>") 'ignore)
(global-set-key (kbd "M-<mouse-1>") 'mc/add-cursor-on-click)
(global-set-key (kbd "C-M-<up>") (lambda () (interactive) (mc/mark-previous-lines 1)))
(global-set-key (kbd "C-M-<down>") (lambda () (interactive) (mc/mark-next-lines 1)))

;; --- Word Deletion (without kill ring) ---
(global-set-key (kbd "M-<backspace>") 'my-backward-delete-word)
(global-set-key (kbd "M-d") 'my-delete-word)
(global-set-key (kbd "M-<delete>") 'my-delete-word)
(global-set-key (kbd "C-<backspace>") 'my-backward-delete-word)

;; --- Misc ---
(global-set-key (kbd "C-e") 'my-copy-path-with-line)
(global-set-key (kbd "C-!") 'my-insert-shell-command-output)
(global-set-key (kbd "C-<f4>") 'my-toggle-macro-recording)
(global-set-key (kbd "<f4>") 'my-call-macro)

;; --- Minibuffer Keybindings ---
(define-key minibuffer-local-filename-completion-map (kbd "C-2") 'my-find-file-right-pane)

;; --- Isearch Keybindings ---
(define-key isearch-mode-map (kbd "<return>") 'isearch-repeat-forward)
(define-key isearch-mode-map (kbd "S-<return>") 'isearch-repeat-backward)
(define-key isearch-mode-map (kbd "<backspace>") 'isearch-del-char)
(define-key isearch-mode-map (kbd "C-v") 'isearch-yank-kill)
(define-key isearch-mode-map (kbd "<escape>") 'my-isearch-cancel-or-exit)
(define-key isearch-mode-map (kbd "C-g") 'my-isearch-cancel-or-exit)

;;; ============================================================================
;;; CUSTOM MINOR MODE (for keybinding overrides)
;;; ============================================================================

(defvar my-keys-minor-mode-map
  (let ((map (make-sparse-keymap)))
  (define-key map (kbd "M-p") 'backward-paragraph)
  (define-key map (kbd "M-n") 'forward-paragraph)
  (define-key map (kbd "C-o") 'next-multiframe-window)
  (define-key map (kbd "C-1") 'my-select-left-pane)
  (define-key map (kbd "C-2") 'my-select-right-pane)
  (define-key map (kbd "C-3") 'switch-to-buffer)
  (define-key map (kbd "C-4") 'find-file)
  (define-key map (kbd "C-j") 'dabbrev-expand)
  (define-key map (kbd "C-d") 'my-mc-mark-next-like-this)
  (define-key map (kbd "C-S-d") 'mc/mark-previous-like-this-word)
  (define-key map (kbd "C-S-a") 'mc/mark-all-like-this)
    map)
  "my-keys-minor-mode keymap.")

(define-minor-mode my-keys-minor-mode
  "A minor mode so that my key settings override annoying major modes."
  :init-value t
  :lighter "")

;; don't enable override keymap in minibuffer
(defun my-minibuffer-setup-hook ()
 (my-keys-minor-mode 0))
(add-hook 'minibuffer-setup-hook 'my-minibuffer-setup-hook)

(my-keys-minor-mode 1)

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Navigation
;;; ============================================================================

(defun my-smart-home ()
  "Move to first non-whitespace char, or beginning of line if already there."
  (interactive "^")
  (let ((orig-point (point)))
    (back-to-indentation)
    (when (= orig-point (point))
      (move-beginning-of-line 1))))

(defun my-get-top-windows ()
  "Get windows in the top portion of the frame (not bottom compilation)."
  (let ((windows '()))
    (walk-windows
     (lambda (w)
       (when (window-at-side-p w 'top)
         (push w windows))))
    (sort windows (lambda (a b) (< (car (window-edges a)) (car (window-edges b)))))))

(defun my-select-left-pane ()
  "Select the left pane of the top split."
  (interactive)
  (let ((top-windows (my-get-top-windows)))
    (when top-windows
      (select-window (car top-windows)))))

(defun my-select-right-pane ()
  "Select the right pane of the top split, creating it if needed."
  (interactive)
  (let ((top-windows (my-get-top-windows)))
    (if (>= (length top-windows) 2)
        (select-window (cadr top-windows))
      (when top-windows
        (select-window (car top-windows))
        (split-window-right)
        (other-window 1)))))

(defun my-xref-find-definitions-same-pane ()
  "Find definition and show it in the same pane.
Falls back to dumb-jump if xref fails."
  (interactive)
  (let ((identifier (thing-at-point 'symbol t)))
    (if (null identifier)
        (message "No symbol at point")
      (condition-case nil
          (let ((xrefs (xref-backend-definitions (xref-find-backend) identifier)))
            (if xrefs
                (xref-find-definitions identifier)
              (dumb-jump-go)))
        (error (dumb-jump-go))))))

(defun my-xref-find-definitions-at-click (event)
  "Find definition of the symbol clicked on."
  (interactive "e")
  (mouse-set-point event)
  (my-xref-find-definitions-same-pane))

(defun my-xref-find-references-at-click (event)
  "Find references of the symbol clicked on."
  (interactive "e")
  (mouse-set-point event)
  (xref-find-references (thing-at-point 'symbol t)))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Search & Replace
;;; ============================================================================

(defun my-isearch-forward ()
  "Start isearch, using selected text if region is active."
  (interactive)
  (if (use-region-p)
      (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
        (deactivate-mark)
        (isearch-forward nil 1)
        (setq isearch-string text
              isearch-message text)
        (isearch-update))
    (isearch-forward)))

(defun my-isearch-cancel-or-exit ()
  "Cancel isearch if search string is empty, otherwise exit at current position."
  (interactive)
  (if (string= isearch-string "")
      (isearch-cancel)
    (isearch-exit)))

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

(defun my-project-find-text ()
  "Search for literal text in project."
  (interactive)
  (let* ((initial (when (use-region-p)
                    (buffer-substring-no-properties (region-beginning) (region-end))))
         (text (read-string "Search in project: " initial)))
    (project-find-regexp (regexp-quote text))))

(defun my-project-find-word-at-point ()
  "Search for word under cursor in project."
  (interactive)
  (let ($p1 $p2 word)
    (if (region-active-p)
        (setq $p1 (region-beginning) $p2 (region-end))
      (save-excursion
        (skip-chars-backward "-_A-Za-z0-9")
        (setq $p1 (point))
        (skip-chars-forward "-_A-Za-z0-9")
        (setq $p2 (point))))
    (setq word (buffer-substring-no-properties $p1 $p2))
    (when (> (length word) 0)
      (project-find-regexp (regexp-quote word)))))

(defun my-find-replace ()
  "Find and replace with mode selection: project, file, or selection."
  (interactive)
  (let* ((mode (completing-read "Replace in: " '("file" "project" "selection") nil t))
         (search (read-string "Find: "))
         (replace (read-string (format "Replace '%s' with: " search))))
    (cond
     ((string= mode "project")
      (project-query-replace-regexp (regexp-quote search) replace))
     ((string= mode "file")
      (save-excursion
        (goto-char (point-min))
        (query-replace search replace)))
     ((string= mode "selection")
      (if (use-region-p)
          (query-replace search replace nil (region-beginning) (region-end))
        (message "No region selected."))))))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Line Operations
;;; ============================================================================

(defun my-select-line ()
  "Select the current line. Repeat to select subsequent lines."
  (interactive)
  (if (and (use-region-p) (eq last-command 'my-select-line))
      (forward-line 1)
    (move-beginning-of-line 1)
    (set-mark (point))
    (forward-line 1)))

(defun my-toggle-comment ()
  "Toggle comment on line or region without moving point."
  (interactive)
  (let* ((region-active (use-region-p))
         (start (if region-active (region-beginning) (line-beginning-position)))
         (end (if region-active (region-end) (line-end-position))))
    (comment-or-uncomment-region start end)
    (when region-active
      (setq deactivate-mark nil))))

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

(defun my-move-line-up ()
  "Move current line or region up one line."
  (interactive)
  (if (use-region-p)
      (my-move-region-up)
    (let ((col (current-column)))
      (transpose-lines 1)
      (forward-line -2)
      (move-to-column col))))

(defun my-move-line-down ()
  "Move current line or region down one line."
  (interactive)
  (if (use-region-p)
      (my-move-region-down)
    (let ((col (current-column)))
      (forward-line 1)
      (transpose-lines 1)
      (forward-line -1)
      (move-to-column col))))

(defun my-move-region-up ()
  "Move selected region up one line, keeping selection."
  (let* ((rbeg (region-beginning))
         (rend (region-end))
         (beg (save-excursion (goto-char rbeg) (line-beginning-position)))
         (end (save-excursion (goto-char rend) (if (bolp) (point) (1+ (line-end-position)))))
         (offset-from-beg (- rbeg beg))
         (region-len (- rend rbeg))
         (text (delete-and-extract-region beg end)))
    (forward-line -1)
    (let ((new-beg (point)))
      (insert text)
      (set-mark (+ new-beg offset-from-beg))
      (goto-char (+ new-beg offset-from-beg region-len))
      (setq deactivate-mark nil))))

(defun my-move-region-down ()
  "Move selected region down one line, keeping selection."
  (let* ((rbeg (region-beginning))
         (rend (region-end))
         (beg (save-excursion (goto-char rbeg) (line-beginning-position)))
         (end (save-excursion (goto-char rend) (if (bolp) (point) (1+ (line-end-position)))))
         (offset-from-beg (- rbeg beg))
         (region-len (- rend rbeg))
         (lines (count-lines beg end))
         (text (delete-and-extract-region beg end)))
    (forward-line 1)
    (let ((new-beg (point)))
      (insert text)
      (set-mark (+ new-beg offset-from-beg))
      (goto-char (+ new-beg offset-from-beg region-len))
      (setq deactivate-mark nil))))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Word Deletion
;;; ============================================================================

(defun my-delete-word (arg)
  "Delete characters forward until encountering the end of a word.
With argument ARG, do this that many times.
Does not copy to kill ring."
  (interactive "p")
  (delete-region (point) (progn (forward-word arg) (point))))

(defun my-backward-delete-word (arg)
  "Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times.
Does not copy to kill ring."
  (interactive "p")
  (my-delete-word (- arg)))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Compile Commands
;;; ============================================================================

(defvar my-project-data-dir "~/.emacs.d/project-data/" "Directory to store per-project data.")

(defun my-project-data-file (filename)
  "Get path to FILENAME for current project in project-data dir."
  (let* ((root (project-root (project-current t)))
         (hash (md5 root))
         (dir (expand-file-name hash my-project-data-dir)))
    (unless (file-exists-p dir)
      (make-directory dir t))
    (expand-file-name filename dir)))

(defun my-compile-get-saved-command ()
  "Get saved compile command for current project."
  (let ((file (my-project-data-file "compile-command")))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (string-trim (buffer-string))))))

(defun my-compile-save-command (cmd)
  "Save compile command CMD for current project."
  (let ((file (my-project-data-file "compile-command")))
    (with-temp-file file
      (insert cmd))))

(defun my-compile-custom ()
  "Run a custom compile command in the project root."
  (interactive)
  (let* ((default-directory (project-root (project-current t)))
         (saved (my-compile-get-saved-command))
         (cmd (read-string "Command: " saved)))
    (my-compile-save-command cmd)
    (compile cmd)))

(defun my-compile-last ()
  "Run last compile command, or prompt for one if none has been run."
  (interactive)
  (let* ((default-directory (project-root (project-current t)))
         (cmd (my-compile-get-saved-command)))
    (if cmd
        (compile cmd)
      (my-compile-custom))))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - CTAGS
;;; ============================================================================

(defun my-tags-get-saved ()
  "Get saved TAGS file path for current project."
  (when (project-current)
    (let ((file (my-project-data-file "tags-file")))
      (when (file-exists-p file)
        (with-temp-buffer
          (insert-file-contents file)
          (string-trim (buffer-string)))))))

(defun my-tags-save (tags-path)
  "Save TAGS file path for current project."
  (when (project-current)
    (let ((file (my-project-data-file "tags-file")))
      (with-temp-file file
        (insert tags-path)))))

(defun my-tags-load ()
  "Load saved TAGS file for current project."
  (let ((saved (my-tags-get-saved)))
    (when (and saved (file-exists-p saved))
      (visit-tags-table saved t))))

(add-hook 'find-file-hook #'my-tags-load)

(defun ctags-generate ()
  "Generate TAGS file using ctags in project root or current directory."
  (interactive)
  (let* ((default-directory (or (and (project-current)
                                     (project-root (project-current)))
                                default-directory))
         (tags-path (expand-file-name "TAGS" default-directory)))
    (message "Generating TAGS in %s..." default-directory)
    (shell-command "ctags -e -R --exclude=.git --exclude=log *")
    (my-tags-save tags-path)
    (visit-tags-table tags-path)
    (message "TAGS generated and saved: %s" tags-path)))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - File Operations
;;; ============================================================================

(defvar my--find-file-right-pane nil)

(defun my-find-file-right-pane ()
  "Open file in right pane from find-file minibuffer."
  (interactive)
  (setq my--find-file-right-pane (expand-file-name (minibuffer-contents)))
  (abort-recursive-edit))

(defun my-find-file-right-pane-after ()
  "Actually open the file in right pane."
  (when my--find-file-right-pane
    (let ((file my--find-file-right-pane))
      (setq my--find-file-right-pane nil)
      (when (one-window-p)
        (split-window-right))
      (other-window 1)
      (find-file file))))

(add-hook 'minibuffer-exit-hook 'my-find-file-right-pane-after)

(defun my-copy-path-with-line ()
  "Copy the current file path with line number to clipboard."
  (interactive)
  (if buffer-file-name
      (let ((path-with-line (format "%s:%d" buffer-file-name (line-number-at-pos))))
        (kill-new path-with-line)
        (message "Copied: %s" path-with-line))
    (message "Buffer has no file.")))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Theme Selection
;;; ============================================================================

(add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
(defvar my-current-theme 'bedroom "Currently active theme.")

(defun my-select-theme ()
  "Select and load a theme from all available themes."
  (interactive)
  (let* ((themes (append '("default" "default-dark") (mapcar #'symbol-name (custom-available-themes))))
         (choice (completing-read "Theme: " themes nil t)))
    (when my-current-theme
      (disable-theme my-current-theme))
    (cond
     ((string= choice "default")
      (set-foreground-color "black")
      (set-background-color "white")
      (setq my-current-theme nil))
     ((string= choice "default-dark")
      (set-foreground-color "white")
      (set-background-color "black")
      (setq my-current-theme nil))
     (t
      (setq my-current-theme (intern choice))
      (load-theme my-current-theme t)))))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Zoom
;;; ============================================================================

(defvar my-default-font-height (face-attribute 'default :height))

(defun my-global-zoom-in ()
  (interactive)
  (set-face-attribute 'default nil :height (+ (face-attribute 'default :height) 10)))

(defun my-global-zoom-out ()
  (interactive)
  (set-face-attribute 'default nil :height (- (face-attribute 'default :height) 10)))

(defun my-global-zoom-reset ()
  (interactive)
  (set-face-attribute 'default nil :height my-default-font-height))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Buffer Management
;;; ============================================================================

(defun kill-other-buffers ()
  "Kill all buffers except the current one and close other panes."
  (interactive)
  (let ((current (current-buffer)))
    (dolist (buf (buffer-list))
      (unless (eq buf current)
        (let ((proc (get-buffer-process buf)))
          (when proc
            (let ((pid (process-id proc)))
              (when pid
                (my-kill-process-tree pid)))
            (set-process-query-on-exit-flag proc nil)))
        (with-current-buffer buf
          (set-buffer-modified-p nil))
        (kill-buffer buf))))
  (setq recentf-list nil)
  (delete-other-windows))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Window Management
;;; ============================================================================

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

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Rectangle Selection
;;; ============================================================================

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

;;; ============================================================================
;;; CUSTOM FUNCTIONS - External Tools
;;; ============================================================================

(defun my-file-manager-command ()
  (interactive)
  (cond ((eq system-type 'windows-nt)
         (shell-command "explorer.exe ."))
        ((eq system-type 'darwin)
         (shell-command "open ."))
        ((eq system-type 'gnu/linux)
         (shell-command "setsid -f nautilus . >/dev/null 2>&1"))))

(defun my-terminal-emulator-command ()
  (interactive)
  (cond ((eq system-type 'windows-nt)
     (let ((proc (start-process "cmd" nil "cmd.exe" "/C" "start" "cmd.exe")))
       (set-process-query-on-exit-flag proc nil)))
    ((eq system-type 'gnu/linux)
     (shell-command "setsid -f gnome-terminal . >/dev/null 2>&1"))))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Emacs Config
;;; ============================================================================

(defun reload-emacs-config ()
  "Reload the Emacs configuration file."
  (interactive)
  (load-file "~/.emacs.d/init.el")
  (message "Emacs config reloaded."))

(defun edit-emacs-config ()
  "Open the Emacs configuration file for editing."
  (interactive)
  (find-file "~/.emacs.d/init.el"))

;;; ============================================================================
;;; CUSTOM FUNCTIONS - Misc
;;; ============================================================================

(defun my-test ()
  (interactive)
  (message "Hello world!"))

(defun lipsum ()
  "Insert lorem ipsum placeholder text."
  (interactive)
  (insert "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."))

(defun my-mc-mark-next-like-this ()
  "VSCode-style C-d: first press selects word, subsequent presses add cursors."
  (interactive)
  (if (use-region-p)
      (progn
        (mc/mark-next-like-this 1)
        (mc/maybe-multiple-cursors-mode))
    (let ((bounds (bounds-of-thing-at-point 'symbol)))
      (when bounds
        (goto-char (car bounds))
        (set-mark (cdr bounds))
        (activate-mark)))))

(defun my-insert-shell-command-output ()
  "Prompt for a shell command and insert its output at point."
  (interactive)
  (let ((command (read-string "Shell command: ")))
    (insert (string-trim-right (shell-command-to-string command)))))

(defun my-toggle-macro-recording ()
  "Toggle keyboard macro recording. Start if not recording, stop if recording."
  (interactive)
  (if defining-kbd-macro
      (progn
        (kmacro-end-macro nil)
        (message "Macro recorded. Press F4 to replay."))
    (kmacro-start-macro nil)
    (message "Recording macro... Press C-<f4> to stop.")))

(defun my-call-macro ()
  "Call last macro. If region is active, run macro N times where N is number of selected lines.
All changes from a multi-line macro execution are undoable as a single operation."
  (interactive)
  (if (use-region-p)
      (let ((lines (count-lines (region-beginning) (region-end)))
            (change-group (prepare-change-group)))
        (goto-char (region-beginning))
        (deactivate-mark)
        (unwind-protect
            (progn
              (activate-change-group change-group)
              (kmacro-call-macro lines))
          (undo-amalgamate-change-group change-group)))
    (kmacro-call-macro 1)))

;;; ============================================================================
;;; TWEAKS & FIXES
;;; ============================================================================

;; fix isearch wrapping behavior
(defadvice isearch-search (after isearch-no-fail activate)
  (unless isearch-success
    (ad-disable-advice 'isearch-search 'after 'isearch-no-fail)
    (ad-activate 'isearch-search)
    (isearch-repeat (if isearch-forward 'forward))
    (ad-enable-advice 'isearch-search 'after 'isearch-no-fail)
    (ad-activate 'isearch-search)))

;; go to match beginning after isearch
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

;;; ============================================================================
;;; APPEARANCE & THEME
;;; ============================================================================

;; (set-face-attribute 'default nil :font "Consolas-15")

(load-theme 'bedroom t)

;;; init.el ends here
