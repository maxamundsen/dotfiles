;;; focus-theme.el --- Focus dark color theme -*- lexical-binding: t; -*-

;;; Commentary:
;; Default theme from the Focus Editor.
;;
;; https://focus-editor.dev/
;; https://github.com/focus-editor/focus

;;; Code:

(deftheme focus
  "Focus dark color theme.")

(custom-theme-set-faces
 'focus
 ;; Basic faces
 '(default ((t (:foreground "#BFC9DB" :background "#15212A"))))
 '(cursor ((t (:background "#26B2B2"))))
 '(region ((t (:background "#1C4449"))))
 '(hl-line ((t (:background "#18262F"))))
 '(highlight ((t (:background "#1C4449"))))
 '(secondary-selection ((t (:background "#1C4449"))))
 '(lazy-highlight ((t (:background "#8E772E"))))
 '(isearch ((t (:background "#8E772E" :foreground "#FFFFFF"))))
 '(isearch-fail ((t (:background "#772222"))))
 '(match ((t (:background "#1C4449"))))

 ;; Mode line
 '(mode-line ((t (:background "#1C303A" :foreground "#BFC9DB"))))
 '(mode-line-inactive ((t (:background "#10191F" :foreground "#87919D"))))
 '(mode-line-buffer-id ((t (:foreground "#BFC9DB" :weight bold))))

 ;; Borders and dividers
 '(vertical-border ((t (:foreground "#10191F"))))
 '(fringe ((t (:background "#15212A"))))
 '(window-divider ((t (:foreground "#1C4449"))))
 '(window-divider-first-pixel ((t (:foreground "#15212A"))))
 '(window-divider-last-pixel ((t (:foreground "#1C4449"))))

 ;; Tab line
 '(tab-line ((t (:background "#1A2831" :foreground "#BFC9DB"))))
 '(tab-line-tab ((t (:background "#1A2831" :foreground "#BFC9DB"))))
 '(tab-line-tab-current ((t (:background "#21333F" :foreground "#BFC9DB"))))
 '(tab-line-tab-inactive ((t (:background "#10191F" :foreground "#87919D"))))

 ;; Line numbers
 '(line-number ((t (:foreground "#87919D" :background "#15212A"))))
 '(line-number-current-line ((t (:foreground "#BFC9DB" :background "#18262F"))))

 ;; Font lock faces
 '(font-lock-builtin-face ((t (:foreground "#E0AD82"))))
 '(font-lock-comment-face ((t (:foreground "#87919D"))))
 '(font-lock-comment-delimiter-face ((t (:foreground "#87919D"))))
 '(font-lock-doc-face ((t (:foreground "#87919D"))))
 '(font-lock-string-face ((t (:foreground "#D4BC7D"))))
 '(font-lock-keyword-face ((t (:foreground "#E67D74"))))
 '(font-lock-function-name-face ((t (:foreground "#D0C5A9"))))
 '(font-lock-variable-name-face ((t (:foreground "#BFC9DB"))))
 '(font-lock-constant-face ((t (:foreground "#D699B5"))))
 '(font-lock-type-face ((t (:foreground "#82AAA3"))))
 '(font-lock-warning-face ((t (:foreground "#F8AD34"))))
 '(font-lock-negation-char-face ((t (:foreground "#E67D74"))))
 '(font-lock-preprocessor-face ((t (:foreground "#E67D74"))))
 '(font-lock-regexp-grouping-backslash ((t (:foreground "#E0AD82"))))
 '(font-lock-regexp-grouping-construct ((t (:foreground "#E0AD82"))))

 ;; Parenthesis matching
 '(show-paren-match ((t (:background "#1C4449" :foreground "#FFFFFF"))))
 '(show-paren-mismatch ((t (:background "#772222" :foreground "#FFFFFF"))))

 ;; Minibuffer
 '(minibuffer-prompt ((t (:foreground "#26B2B2"))))

 ;; Compilation
 '(compilation-info ((t (:foreground "#227722"))))
 '(compilation-warning ((t (:foreground "#F8AD34"))))
 '(compilation-error ((t (:foreground "#FF0000"))))
 '(compilation-mode-line-exit ((t (:foreground "#227722"))))
 '(compilation-mode-line-fail ((t (:foreground "#772222"))))

 ;; Flymake
 '(flymake-error ((t (:underline (:style wave :color "#772222")))))
 '(flymake-warning ((t (:underline (:style wave :color "#986032")))))
 '(flymake-note ((t (:underline (:style wave :color "#87919D")))))

 ;; Flyspell
 '(flyspell-incorrect ((t (:underline (:style wave :color "#772222")))))
 '(flyspell-duplicate ((t (:underline (:style wave :color "#986032")))))

 ;; Ivy
 '(ivy-current-match ((t (:background "#1C4449" :foreground "#BFC9DB"))))
 '(ivy-minibuffer-match-face-1 ((t (:foreground "#599999"))))
 '(ivy-minibuffer-match-face-2 ((t (:foreground "#26B2B2" :weight bold))))
 '(ivy-minibuffer-match-face-3 ((t (:foreground "#E0AD82" :weight bold))))
 '(ivy-minibuffer-match-face-4 ((t (:foreground "#D699B5" :weight bold))))
 '(ivy-confirm-face ((t (:foreground "#227722"))))
 '(ivy-match-required-face ((t (:foreground "#772222"))))

 ;; Dired
 '(dired-directory ((t (:foreground "#82AAA3"))))
 '(dired-symlink ((t (:foreground "#26B2B2"))))
 '(dired-ignored ((t (:foreground "#87919D"))))

 ;; Diff
 '(diff-added ((t (:background "#226022" :foreground "#BFC9DB"))))
 '(diff-removed ((t (:background "#772222" :foreground "#BFC9DB"))))
 '(diff-changed ((t (:background "#986032" :foreground "#BFC9DB"))))
 '(diff-header ((t (:background "#1A2831" :foreground "#BFC9DB"))))
 '(diff-file-header ((t (:background "#21333F" :foreground "#BFC9DB"))))
 '(diff-hunk-header ((t (:background "#1C4449" :foreground "#BFC9DB"))))

 ;; Ediff
 '(ediff-current-diff-A ((t (:background "#772222"))))
 '(ediff-current-diff-B ((t (:background "#226022"))))
 '(ediff-current-diff-C ((t (:background "#986032"))))
 '(ediff-fine-diff-A ((t (:background "#993333"))))
 '(ediff-fine-diff-B ((t (:background "#338033"))))
 '(ediff-fine-diff-C ((t (:background "#B87842"))))

 ;; Eglot
 '(eglot-highlight-symbol-face ((t (:background "#1C4449"))))

 ;; Link
 '(link ((t (:foreground "#26B2B2" :underline t))))
 '(link-visited ((t (:foreground "#D699B5" :underline t))))

 ;; Custom/widget faces
 '(custom-group-tag ((t (:foreground "#82AAA3" :weight bold))))
 '(custom-variable-tag ((t (:foreground "#82AAA3" :weight bold))))
 '(widget-field ((t (:background "#21333F" :foreground "#BFC9DB"))))
 '(widget-single-line-field ((t (:background "#21333F" :foreground "#BFC9DB"))))

 ;; Error, warning, success
 '(error ((t (:foreground "#FF0000"))))
 '(warning ((t (:foreground "#F8AD34"))))
 '(success ((t (:foreground "#227722")))))

(provide-theme 'focus)

;;; focus-theme.el ends here
