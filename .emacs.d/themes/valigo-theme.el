;;; valigo-theme.el --- Dark purple-grey theme with gold accents -*- lexical-binding: t; -*-

;;; Commentary:
;; Based on ef-dream theme with customizations from valignatev/dotemacs.
;; A dark theme with warm gold accents and muted purple-grey tones.

;;; Code:

(deftheme valigo
  "Dark purple-grey theme with gold accents.")

(custom-theme-set-faces
 'valigo
 ;; Basic faces
 '(default ((t (:foreground "#efd5c5" :background "#131015"))))
 '(cursor ((t (:background "#f3c09a"))))
 '(region ((t (:background "#544a50"))))
 '(hl-line ((t (:background "#232224"))))
 '(highlight ((t (:background "#503240"))))
 '(secondary-selection ((t (:background "#412f4f"))))
 '(lazy-highlight ((t (:background "#8f665f"))))
 '(isearch ((t (:background "#957856" :foreground "#efd5c5"))))
 '(isearch-fail ((t (:background "#5a3142"))))
 '(match ((t (:background "#503240"))))

 ;; Mode line
 '(mode-line ((t (:background "#472b00" :foreground "#f2ddcf"))))
 '(mode-line-inactive ((t (:background "#2a272c" :foreground "#8f8886"))))
 '(mode-line-buffer-id ((t (:foreground "#f2ddcf" :weight bold))))

 ;; Borders and dividers
 '(vertical-border ((t (:foreground "#635850"))))
 '(fringe ((t (:background "#131015"))))
 '(window-divider ((t (:foreground "#635850"))))
 '(window-divider-first-pixel ((t (:foreground "#131015"))))
 '(window-divider-last-pixel ((t (:foreground "#635850"))))
 '(border ((t (:foreground "#635850"))))

 ;; Tab line
 '(tab-line ((t (:background "#322f34" :foreground "#efd5c5"))))
 '(tab-line-tab ((t (:background "#322f34" :foreground "#efd5c5"))))
 '(tab-line-tab-current ((t (:background "#3b393e" :foreground "#efd5c5"))))
 '(tab-line-tab-inactive ((t (:background "#2a272c" :foreground "#8f8886"))))

 ;; Line numbers
 '(line-number ((t (:foreground "#8f8886" :background "#131015"))))
 '(line-number-current-line ((t (:foreground "#efd5c5" :background "#232224"))))

 ;; Font lock faces
 '(font-lock-builtin-face ((t (:foreground "#b0a0cf"))))
 '(font-lock-comment-face ((t (:foreground "#8f8886"))))
 '(font-lock-comment-delimiter-face ((t (:foreground "#8f8886"))))
 '(font-lock-doc-face ((t (:foreground "#8f8886"))))
 '(font-lock-string-face ((t (:foreground "#c0b24f"))))
 '(font-lock-keyword-face ((t (:foreground "#ff9f0a"))))
 '(font-lock-function-name-face ((t (:foreground "#ffaacf"))))
 '(font-lock-variable-name-face ((t (:foreground "#efd5c5"))))
 '(font-lock-constant-face ((t (:foreground "#d0b0ff"))))
 '(font-lock-type-face ((t (:foreground "#6fb3c0"))))
 '(font-lock-warning-face ((t (:foreground "#ff6f6f"))))
 '(font-lock-negation-char-face ((t (:foreground "#ff7a5f"))))
 '(font-lock-preprocessor-face ((t (:foreground "#ff9f0a"))))
 '(font-lock-regexp-grouping-backslash ((t (:foreground "#deb07a"))))
 '(font-lock-regexp-grouping-construct ((t (:foreground "#deb07a"))))

 ;; Parenthesis matching
 '(show-paren-match ((t (:background "#885566" :foreground "#efd5c5"))))
 '(show-paren-mismatch ((t (:background "#a02f50" :foreground "#efd5c5"))))

 ;; Minibuffer
 '(minibuffer-prompt ((t (:foreground "#ff9f0a"))))

 ;; Compilation
 '(compilation-info ((t (:foreground "#51b04f"))))
 '(compilation-warning ((t (:foreground "#d09950"))))
 '(compilation-error ((t (:foreground "#ff6f6f"))))
 '(compilation-mode-line-exit ((t (:foreground "#51b04f"))))
 '(compilation-mode-line-fail ((t (:foreground "#ff6f6f"))))

 ;; Flymake
 '(flymake-error ((t (:underline (:style wave :color "#ff6f6f")))))
 '(flymake-warning ((t (:underline (:style wave :color "#d09950")))))
 '(flymake-note ((t (:underline (:style wave :color "#8f8886")))))

 ;; Flyspell
 '(flyspell-incorrect ((t (:underline (:style wave :color "#ff6f6f")))))
 '(flyspell-duplicate ((t (:underline (:style wave :color "#d09950")))))

 ;; Vertico
 '(vertico-current ((t (:background "#503240" :foreground "#efd5c5"))))
 '(vertico-group-title ((t (:foreground "#8fcfd0"))))
 '(vertico-group-separator ((t (:foreground "#635850"))))
 '(completions-common-part ((t (:foreground "#ff9f0a"))))
 '(completions-first-difference ((t (:foreground "#ffaacf" :weight bold))))

 ;; Dired
 '(dired-directory ((t (:foreground "#57b0ff"))))
 '(dired-symlink ((t (:foreground "#6fb3c0"))))
 '(dired-ignored ((t (:foreground "#8f8886"))))

 ;; Diff
 '(diff-added ((t (:background "#304a4f" :foreground "#efd5c5"))))
 '(diff-removed ((t (:background "#5a3142" :foreground "#efd5c5"))))
 '(diff-changed ((t (:background "#51512f" :foreground "#efd5c5"))))
 '(diff-header ((t (:background "#322f34" :foreground "#efd5c5"))))
 '(diff-file-header ((t (:background "#3b393e" :foreground "#efd5c5"))))
 '(diff-hunk-header ((t (:background "#412f4f" :foreground "#efd5c5"))))
 '(diff-refine-added ((t (:background "#2f6767"))))
 '(diff-refine-removed ((t (:background "#782a4a"))))
 '(diff-refine-changed ((t (:background "#64651f"))))

 ;; Ediff
 '(ediff-current-diff-A ((t (:background "#5a3142"))))
 '(ediff-current-diff-B ((t (:background "#304a4f"))))
 '(ediff-current-diff-C ((t (:background "#51512f"))))
 '(ediff-fine-diff-A ((t (:background "#782a4a"))))
 '(ediff-fine-diff-B ((t (:background "#2f6767"))))
 '(ediff-fine-diff-C ((t (:background "#64651f"))))

 ;; Eglot
 '(eglot-highlight-symbol-face ((t (:background "#412f4f"))))

 ;; Link
 '(link ((t (:foreground "#57b0ff" :underline t))))
 '(link-visited ((t (:foreground "#d0b0ff" :underline t))))

 ;; Custom/widget faces
 '(custom-group-tag ((t (:foreground "#6fb3c0" :weight bold))))
 '(custom-variable-tag ((t (:foreground "#6fb3c0" :weight bold))))
 '(widget-field ((t (:background "#3b393e" :foreground "#efd5c5"))))
 '(widget-single-line-field ((t (:background "#3b393e" :foreground "#efd5c5"))))

 ;; Error, warning, success
 '(error ((t (:foreground "#ff6f6f"))))
 '(warning ((t (:foreground "#d09950"))))
 '(success ((t (:foreground "#51b04f"))))

 ;; Org mode
 '(org-level-1 ((t (:foreground "#ff9f0a"))))
 '(org-level-2 ((t (:foreground "#ffaacf"))))
 '(org-level-3 ((t (:foreground "#6fb3c0"))))
 '(org-level-4 ((t (:foreground "#d0b0ff"))))
 '(org-level-5 ((t (:foreground "#c0b24f"))))
 '(org-level-6 ((t (:foreground "#51b04f"))))
 '(org-level-7 ((t (:foreground "#57b0ff"))))
 '(org-level-8 ((t (:foreground "#8fcfd0")))))

(provide-theme 'valigo)

;;; valigo-theme.el ends here
