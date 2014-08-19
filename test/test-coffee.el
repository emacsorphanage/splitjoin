;;; test-coffee.el --- splitjoin test for CoffeeScript

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

(ert-deftest coffee-postfix-condition-p ()
  "Simple postfix condition."
  (with-coffee-temp-buffer
    "
do_something if false
"
    (forward-cursor-on "do_something")
    (should (splitjoin--postfix-condition-p 'coffee-mode))))

(ert-deftest coffee-postfix-condition-p-member ()
  "Postfix with some special characters."
  (with-coffee-temp-buffer
    "
console.log \"foo\" unless @a == 1
"
    (forward-cursor-on "console")
    (should (splitjoin--postfix-condition-p 'coffee-mode))))

(ert-deftest coffee-postfix-condition-p-false-case ()
  "Invalid case of postfix condition"
  (with-coffee-temp-buffer
    "
if true
   do_something
"
    (forward-cursor-on "if")
    (should-not (splitjoin--postfix-condition-p 'coffee-mode))

    (goto-char (line-end-position))
    (should-not (splitjoin--postfix-condition-p 'coffee-mode))

    (forward-cursor-on "do_something")
    (should-not (splitjoin--postfix-condition-p 'coffee-mode))

    (goto-char (point-max))
    (should-not (splitjoin--postfix-condition-p 'coffee-mode))))

(ert-deftest coffee-block-condition-p-inside-block ()
  "Valid case. Block condition."
  (with-coffee-temp-buffer
    "
if true
   do_something
"
    (forward-cursor-on "do_something")
    (should (splitjoin--block-condition-p 'coffee-mode))))

(ert-deftest coffee-block-condition-p-same-as-beginning-of-block ()
  ""
  (with-coffee-temp-buffer
    "
if true
   do_something
"
    (forward-cursor-on "if")
    (should (splitjoin--block-condition-p 'coffee-mode))

    (forward-cursor-on "true")
    (should (splitjoin--block-condition-p 'coffee-mode))))

(ert-deftest coffee-block-condition-p-has-more-than-one-line ()
  "Invalid case. Block has more than one statements"
  (with-coffee-temp-buffer
    "
if true
   do_something1
   do_something2
"
    (forward-cursor-on "do_something2")
    (should-not (splitjoin--block-condition-p 'coffee-mode))))

(ert-deftest coffee-retrieve-condition-term ()
  ""
  (with-coffee-temp-buffer
    "
if true
   do_something
"
    (forward-cursor-on "do_something")
    (let ((got (splitjoin--retrieve-block-condition 'coffee-mode)))
      (should (string= got "if true")))))

(ert-deftest coffee-retrieve-condition-expression ()
  "retrieve condition expression"
  (with-coffee-temp-buffer
    "
unless  \t   @foo =~ /^HTTP/
   do_something
"
    (forward-cursor-on "HTTP")
    (let ((got (splitjoin--retrieve-block-condition 'coffee-mode)))
      (should (string= got "unless  \t   @foo =~ /^HTTP/")))))

(ert-deftest coffee-splitjoin-block ()
  "block condition"
  (with-coffee-temp-buffer
    "
if true
        do_something
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "^do_something if true" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

(ert-deftest coffee-splitjoin-block-nested ()
  "block conditon in nested block"
  (with-coffee-temp-buffer
    "
if true
        unless false
                do_something
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "^\\s-+do_something unless false$" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

(ert-deftest coffee-splitjoin-postfix ()
  "postfix condition"
  (with-coffee-temp-buffer
    "
console.log \"foo\" unless @a == 1
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "console")
      (call-interactively 'splitjoin)
      (should (string-match-p "unless @a == 1\n\\s-+console.log \"foo\"" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

(ert-deftest coffee-splitjoin-postfix-nested ()
  "postfix condition in block"
  (with-coffee-temp-buffer
    "
if true
        do_something unless i == j
"
    (let ((orig-content (buffer-string)))
      (forward-cursor-on "do_something")
      (call-interactively 'splitjoin)
      (should (string-match-p "unless i == j\n\\s-+do_something" (buffer-string)))
      (call-interactively 'splitjoin)
      (should (string= orig-content (buffer-string))))))

;;; test-coffee.el ends here
