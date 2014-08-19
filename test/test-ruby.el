;;; test-ruby.el ---

;; Copyright (C) 2014 by Syohei YOSHIDA

;; Author: Syohei YOSHIDA <syohex@gmail.com>

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

(require 'ert)
(require 'splitjoin)

(ert-deftest ruby-postfix-condition-p ()
  "Simple postfix condition."
  (with-ruby-temp-buffer
    "
do_something if false
"
    (forward-cursor-on "do_something")
    (should (splitjoin--postfix-condition-p 'ruby-mode))))

(ert-deftest ruby-postfix-condition-p-false-case ()
  "Invalid case of postfix condition."
  (with-ruby-temp-buffer
    "
if true
   do_something
end
"
    (forward-cursor-on "if")
    (should-not (splitjoin--postfix-condition-p 'ruby-mode))

    (goto-char (line-end-position))
    (should-not (splitjoin--postfix-condition-p 'ruby-mode))

    (forward-cursor-on "do_something")
    (should-not (splitjoin--postfix-condition-p 'ruby-mode))

    (forward-cursor-on "end")
    (should-not (splitjoin--postfix-condition-p 'ruby-mode))

    (goto-char (point-max))
    (should-not (splitjoin--postfix-condition-p 'ruby-mode))))

(ert-deftest ruby-block-condition-p-inside-block ()
  "Simple block condition."
  (with-ruby-temp-buffer
    "
if true
   do_something
end
"
    (forward-cursor-on "do_something")
    (should (splitjoin--block-condition-p 'ruby-mode))))

(ert-deftest ruby-block-condition-p-same-as-beginning-of-block ()
  "Block condition check from beginning of block"
  (with-ruby-temp-buffer
    "
if true
   do_something
end
"
    (forward-cursor-on "if")
    (should (splitjoin--block-condition-p 'ruby-mode))

    (forward-cursor-on "true")
    (should (splitjoin--block-condition-p 'ruby-mode))))

(ert-deftest ruby-block-condition-p-same-as-end-of-block ()
  "Block condition check from end of block"
  (with-ruby-temp-buffer
    "
if true
   do_something
end
"
    (forward-cursor-on "end")
    (should (splitjoin--block-condition-p 'ruby-mode))

    (goto-char (line-end-position))
    (should (splitjoin--block-condition-p 'ruby-mode))))

(ert-deftest ruby-block-condition-p-has-more-than-one-line ()
  "Block has more than one statements."
  (with-ruby-temp-buffer
    "
if true
   do_something1
   do_something2
end
"
    (forward-cursor-on "end")
    (should-not (splitjoin--block-condition-p 'ruby-mode))))

(ert-deftest ruby-retrieve-condition-term ()
  "retrieve condition which is term."
  (with-ruby-temp-buffer
    "
if true
   do_something
end
"
    (forward-cursor-on "do_something")
    (let ((got (splitjoin--retrieve-block-condition 'ruby-mode)))
      (should (string= got "if true")))))

(ert-deftest ruby-retrieve-condition-expression ()
  "retrieve condition which is expression."
  (with-ruby-temp-buffer
    "
unless  \t   @foo =~ /^HTTP/
   do_something
end
"
    (forward-cursor-on "end")
    (let ((got (splitjoin--retrieve-block-condition 'ruby-mode)))
      (should (string= got "unless  \t   @foo =~ /^HTTP/")))))

(ert-deftest ruby-splitjoin-block ()
  "splitjoin for block condition."
  (with-ruby-temp-buffer
    "
if true
  do_something
end
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "^do_something if true" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

(ert-deftest ruby-splitjoin-block-nested ()
  "splitjoin for nested block"
  (with-ruby-temp-buffer
    "
if true
  unless false
    do_something
  end
end
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "^\\s-+do_something unless false$" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

(ert-deftest ruby-splitjoin-postfix ()
  "splitjoin for postfix condition"
  (with-ruby-temp-buffer
    "
do_something if true
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "if true\n  do_something\nend" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

(ert-deftest ruby-splitjoin-postfix-nested ()
  "splitjoin for postfix condition in nested block"
  (with-ruby-temp-buffer
    "
if true
  do_something unless i == j
end
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "unless i == j\n\\s-+do_something\n\\s-+end" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

;;; test-ruby.el ends here
