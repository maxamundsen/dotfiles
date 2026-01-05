;;; bedroom-theme.el --- Max's dark color theme -*- lexical-binding: t; -*-

;;; Commentary:
;; A dark color theme based on Max's personal color settings.

;;; Code:

(deftheme bedroom
  "Max's dark color theme.")

(custom-theme-set-faces
 'bedroom
 ;; Basic faces
 '(default ((t (:foreground "#DADEE5" :background "#142B29"))))
 '(cursor ((t (:background "lightgreen"))))
 '(region ((t (:background "#1F4A3A"))))
 '(hl-line ((t (:background "#000000"))))
 '(highlight ((t (:background "#1F4A3A"))))
 '(mode-line ((t (:background "#1E4A3A" :foreground "#DADEE5"))))
 '(mode-line-inactive ((t (:background "#183524" :foreground "#6A8A7A"))))
 '(vertical-border ((t (:foreground "#505050"))))
 '(fringe ((t (:background "#142B29"))))
 '(window-divider ((t (:foreground "#3A5542"))))
 '(window-divider-first-pixel ((t (:foreground "#142B29"))))
 '(window-divider-last-pixel ((t (:foreground "#3A5542"))))
 '(tab-line ((t (:background "#505050" :foreground "#DADEE5"))))
 '(tab-line-tab ((t (:background "#505050" :foreground "#DADEE5"))))
 '(tab-line-tab-current ((t (:background "#505050" :foreground "#DADEE5"))))
 '(tab-line-tab-inactive ((t (:background "#383838" :foreground "#888888"))))

 ;; Font lock faces
 '(font-lock-builtin-face ((t (:foreground "#DADEE5"))))
 '(font-lock-comment-face ((t (:foreground "#87919D"))))
 '(font-lock-string-face ((t (:foreground "#d3b58d"))))
 '(font-lock-keyword-face ((t (:foreground "#c47616"))))
 '(font-lock-function-name-face ((t (:foreground "#DADEE5"))))
 '(font-lock-variable-name-face ((t (:foreground "#DADEE5"))))
 '(font-lock-constant-face ((t (:foreground "#BBABC3"))))
 '(font-lock-type-face ((t (:foreground "#85B8DE"))))
 '(font-lock-warning-face ((t (:foreground "#FC2D07"))))

 ;; Dired
 '(dired-directory ((t (:foreground "#5FD7AF" :weight bold))))
 '(dired-symlink ((t (:foreground "#87919D"))))

 ;; Custom/widget faces
 '(custom-group-tag ((t (:underline t :foreground "lightgreen"))))
 '(custom-variable-tag ((t (:underline t :foreground "lightgreen"))))
 '(widget-field ((t (:foreground "white"))))
 '(widget-single-line-field ((t (:background "darkgray")))))

(provide-theme 'bedroom)

;;; bedroom-theme.el ends here
