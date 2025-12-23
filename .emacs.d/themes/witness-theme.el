;;; witness-theme.el --- Witness color theme -*- lexical-binding: t; -*-

;;; Commentary:
;; A dark teal color theme.

;;; Code:

(deftheme witness
  "Witness color theme - dark teal with green accents.")

(custom-theme-set-faces
 'witness
 ;; Basic faces
 '(default ((t (:foreground "#d3b58d" :background "#072626"))))
 '(cursor ((t (:background "lightgreen"))))
 '(region ((t (:background "blue"))))
 '(highlight ((t (:foreground "navyblue" :background "darkseagreen2"))))
 '(mode-line ((t (:inverse-video t))))

 ;; Font lock faces
 '(font-lock-builtin-face ((t (:foreground "lightgreen"))))
 '(font-lock-comment-face ((t (:foreground "#3fdf1f"))))
 '(font-lock-string-face ((t (:foreground "#0fdfaf"))))
 '(font-lock-keyword-face ((t (:foreground "white"))))
 '(font-lock-function-name-face ((t (:foreground "white"))))
 '(font-lock-variable-name-face ((t (:foreground "#c8d4ec"))))
 '(font-lock-warning-face ((t (:foreground "#504038"))))

 ;; Custom/widget faces
 '(custom-group-tag ((t (:underline t :foreground "lightblue"))))
 '(custom-variable-tag ((t (:underline t :foreground "lightblue"))))
 '(widget-field ((t (:foreground "white"))))
 '(widget-single-line-field ((t (:background "darkgray")))))

(provide-theme 'witness)

;;; witness-theme.el ends here
