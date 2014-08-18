;;; splitjoin.el --- splitjoin -*- lexical-binding: t; -*-

;; Copyright (C) 2014 by Syohei YOSHIDA

;; Author: Syohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/syohex/emacs-splitjoin
;; Version: 0.01

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)

;; Suppress byte-compile warnings
(declare-function ruby-beginning-of-block "ruby-mode")
(declare-function ruby-end-of-block "ruby-mode")

(defconst splitjoin--supported-modes
  '(ruby-mode coffee-mode))

(defsubst splitjoin--in-string-or-comment-p ()
  (nth 8 (syntax-ppss)))

(defsubst splitjoin--current-line ()
  (buffer-substring-no-properties (line-beginning-position) (line-end-position)))

(defun splitjoin--block-condition-ruby-p ()
  (let ((curline (line-number-at-pos))
        beginning-line end-line)
    (back-to-indentation)
    (unless (looking-at "\\(?:if\\|unless\\|while\\|until\\)\\s-*")
      (ruby-beginning-of-block))
    (when (looking-at "\\(?:if\\|unless\\|while\\|until\\)\\s-*\\(.+\\)\\s-*$")
      (setq beginning-line (line-number-at-pos))
      (ruby-end-of-block)
      (when (looking-at-p "\\(end\\|}\\)\\>")
        (setq end-line (line-number-at-pos))
        (if (not (and (<= beginning-line curline) (<= curline end-line)))
            (error "Here is not condition block")
          (if (<= (- end-line beginning-line) 2)
              t
            (prog1 nil
              (message "This block is more than 2 lines."))))))))

(defun splitjoin--block-condition-coffee-p ()
  (goto-char (line-beginning-position))
  (back-to-indentation)
  (let ((block-start-re "\\=\\(?:if\\|unless\\|while\\|until\\)\\s-*.+$")
        curindent)
    (unless (looking-at-p block-start-re)
      (setq curindent (current-indentation))
      (forward-line -1)
      (back-to-indentation))
    (let ((block-indent (current-indentation)))
      (when (and (looking-at-p block-start-re)
                 (or (not curindent) (< block-indent curindent)))
        (let ((lines 0)
              finish)
          (while (not finish)
            (forward-line 1)
            (let ((indent (current-indentation))
                  (line (splitjoin--current-line)))
              (when (and (< block-indent indent)
                         (not (string-match-p "\\`\\s-*\\'" line)))
                (cl-incf lines))
              (when (or (eobp) (>= block-indent (current-indentation)))
                (setq finish t))))
          (= lines 1))))))

(defun splitjoin--block-condition-p (mode)
  (save-excursion
    (cl-case mode
      (ruby-mode (splitjoin--block-condition-ruby-p))
      (coffee-mode (splitjoin--block-condition-coffee-p)))))

(defun splitjoin--postfix-condition-ruby-p ()
  (save-excursion
    (back-to-indentation)
    (unless (looking-at-p "\\=\\(?:if\\|unless\\|while\\|until\\)")
      (goto-char (line-end-position))
      (looking-back "\\(?:if\\|unless\\|while\\|until\\)\\s-+\\(.+\\)\\s-*\\="))))

(defun splitjoin--postfix-condition-p (mode)
  (cl-case mode
    ((ruby-mode coffee-mode) (splitjoin--postfix-condition-ruby-p))))

(defun splitjoin--retrieve-block-condition-ruby ()
  (save-excursion
    (back-to-indentation)
    (unless (looking-at-p "\\=\\(?:if\\|unless\\|while\\|until\\)\\b")
      (ruby-beginning-of-block))
    ;; TODO condition has multiple lines
    (let ((cond-start (point)))
      (goto-char (line-end-position))
      (skip-chars-backward " \t")
      (buffer-substring-no-properties cond-start (point)))))

(defun splitjoin--retrieve-block-condition (mode)
  (cl-case mode
    (ruby-mode (splitjoin--retrieve-block-condition-ruby))))

(defun splitjoin--to-postfix-condition-ruby (condition)
  (save-excursion
    (let (start end body)
      (back-to-indentation)
      (unless (looking-at-p "\\=\\(?:if\\|unless\\|while\\|until\\)\\b")
        (ruby-beginning-of-block))
      (setq start (point))
      (forward-line 1)
      (back-to-indentation)
      (let ((body-start (point)))
        (goto-char (line-end-position))
        (delete-horizontal-space)
        (setq body (buffer-substring-no-properties body-start (point))))
      (ruby-end-of-block)
      (skip-chars-forward "^ \t\r\n")
      (setq end (point))
      (delete-region start end)
      (insert body " " condition)
      (indent-for-tab-command))))

(defun splitjoin--to-postfix-condition (mode)
  (let ((condition (splitjoin--retrieve-block-condition mode)))
    (cl-case mode
      (ruby-mode (splitjoin--to-postfix-condition-ruby condition)))))

(defun splitjoin--to-block-condition-ruby (has-end)
  (save-excursion
    (goto-char (line-beginning-position))
    (back-to-indentation)
    (let ((start (point))
          (end (line-end-position))
          (regexp "\\=\\(.+\\)\\s-+\\(\\(?:if\\|unless\\|while\\|until\\)\\s-*.+\\)\\s-*$"))
      (if (not (re-search-forward regexp end t))
          (error "Error: Cannot get condition expression.")
        (let ((body (match-string-no-properties 1))
              (condition (match-string-no-properties 2))
              block-start)
          (delete-region start end)
          (setq block-start (point))
          (insert condition "\n" body)
          (when has-end
            (insert "\nend"))
          (indent-region block-start (point)))))))

(defun splitjoin--to-block-condition (mode)
  (cl-case mode
    (ruby-mode (splitjoin--to-block-condition-ruby t))
    (coffee-mode (splitjoin--to-block-condition-ruby nil))))

;;;###autoload
(defun splitjoin ()
  (interactive)
  (unless (memq major-mode splitjoin--supported-modes)
    (error "Error: '%s' is not supported" major-mode))
  (if (splitjoin--postfix-condition-p major-mode)
      (splitjoin--to-block-condition major-mode)
    (if (splitjoin--block-condition-p major-mode)
        (splitjoin--to-postfix-condition major-mode)
      (error "Here is neither postfix condition nor block condition"))))

(provide 'splitjoin)

;;; splitjoin.el ends here
