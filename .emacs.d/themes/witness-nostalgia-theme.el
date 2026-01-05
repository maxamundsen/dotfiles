;;; witness-nostalgia-theme.el --- Witness color theme -*- lexical-binding: t; -*-

;;; Commentary:
;; A dark teal color theme.

;;; Code:

(deftheme witness-nostalgia
  "Witness nostalgia color theme - gray with green and yellow accents.")

(custom-theme-set-faces
 'witness-nostalgia
 ;; Basic faces
 '(default ((t (:foreground "#d3b58d" :background "#292929"))))
 '(cursor ((t (:background "lightgreen"))))
 '(region ((t (:background "blue"))))
 '(highlight ((t (:foreground "navyblue" :background "darkseagreen2"))))
 '(mode-line ((t (:inverse-video t))))

 ;; Font lock faces
 '(font-lock-builtin-face ((t (:foreground "lightgreen"))))
 '(font-lock-comment-face ((t (:foreground "#FFFF00"))))
 '(font-lock-string-face ((t (:foreground "#BEBEBE"))))
 '(font-lock-keyword-face ((t (:foreground "white"))))
 '(font-lock-function-name-face ((t (:foreground "white"))))
 '(font-lock-variable-name-face ((t (:foreground "#c8d4ec"))))
 '(font-lock-warning-face ((t (:foreground "#504038"))))

 ;; Custom/widget faces
 '(custom-group-tag ((t (:underline t :foreground "lightblue"))))
 '(custom-variable-tag ((t (:underline t :foreground "lightblue"))))
 '(widget-field ((t (:foreground "white"))))
 '(widget-single-line-field ((t (:background "darkgray")))))

(provide-theme 'witness-nostalgia)

;;; witness-theme.el ends here
