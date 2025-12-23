;;; bedroom-theme.el --- Max's dark color theme -*- lexical-binding: t; -*-

;;; Commentary:
;; A dark color theme based on Max's personal color settings.

;;; Code:

(deftheme bedroom
  "Max's dark color theme.")

(custom-theme-set-faces
 'bedroom
 ;; Basic faces
 '(default ((t (:foreground "#DADEE5" :background "#141B2B"))))
 '(cursor ((t (:background "#FF69B4"))))
 '(region ((t (:background "#15285A"))))
 '(hl-line ((t (:background "#000000"))))
 '(highlight ((t (:background "#15285A"))))
 '(mode-line ((t (:background "#d3b58d" :foreground "#141B2B"))))
 '(mode-line-inactive ((t (:inverse-video t))))

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

 ;; Custom/widget faces
 '(custom-group-tag ((t (:underline t :foreground "lightblue"))))
 '(custom-variable-tag ((t (:underline t :foreground "lightblue"))))
 '(widget-field ((t (:foreground "white"))))
 '(widget-single-line-field ((t (:background "darkgray")))))

(provide-theme 'bedroom)

;;; bedroom-theme.el ends here
