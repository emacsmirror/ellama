;;; test-ellama.el --- Ellama tests -*- lexical-binding: t; package-lint-main-file: "../ellama.el"; -*-

;; Copyright (C) 2023-2025  Free Software Foundation, Inc.

;; Author: Sergey Kostyaev <sskostyaev@gmail.com>

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Ellama tests.
;;

;;; Code:

(require 'cl-lib)
(require 'ellama)
(require 'ellama-context)
(require 'ellama-transient)
(require 'ert)
(require 'llm-fake)

(ert-deftest test-ellama--code-filter ()
  (should (equal "" (ellama--code-filter "")))
  (should (equal "(hello)" (ellama--code-filter "(hello)")))
  (should (equal "(hello)\n" (ellama--code-filter "```lisp\n(hello)\n```"))))

(ert-deftest test-ellama-code-improve ()
  (let ((original "(hello)\n")
        (improved "```lisp\n(hello)\n```")
        (ellama-provider (make-llm-fake))
        prev-lines)
    (with-temp-buffer
      (insert original)
      (cl-letf (((symbol-function 'llm-chat-streaming)
                 (lambda (_provider prompt partial-callback response-callback _error-callback _multi-output)
                   (should (string-match original (llm-chat-prompt-to-text prompt)))
                   (dolist (s (string-lines improved))
                     (funcall partial-callback `(:text ,(concat prev-lines s)))
                     (setq prev-lines (concat prev-lines s)))
                   (funcall response-callback `(:text ,improved)))))
        (ellama-code-improve)
        (should (equal original (buffer-string)))))))

(ert-deftest test-ellama-context-element-format-buffer-markdown ()
  (let ((element (ellama-context-element-buffer :name "*scratch*")))
    (should (equal "```emacs-lisp\n(display-buffer \"*scratch*\")\n```\n"
                   (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-buffer-org-mode ()
  (let ((element (ellama-context-element-buffer :name "*scratch*")))
    (should (equal "[[elisp:(display-buffer \"*scratch*\")][*scratch*]]"
                   (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-file-markdown ()
  (let ((element (ellama-context-element-file :name "LICENSE")))
    (should (equal "[LICENSE](<LICENSE>)"
                   (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-file-org-mode ()
  (let ((element (ellama-context-element-file :name "LICENSE")))
    (should (equal "[[file:LICENSE][LICENSE]]"
                   (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-info-node-markdown ()
  (let ((element (ellama-context-element-info-node :name "(dir)Top")))
    (should (equal "```emacs-lisp\n(info \"(dir)Top\")\n```\n"
                   (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-info-node-org-mode ()
  (let ((element (ellama-context-element-info-node :name "(dir)Top")))
    (should (equal "[[(dir)Top][(dir)Top]]"
                   (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-text-markdown ()
  (let ((element (ellama-context-element-text :content "123")))
    (should (equal "123" (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-text-org-mode ()
  (let ((element (ellama-context-element-text :content "123")))
    (should (equal "123" (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-webpage-quote-disabled-markdown ()
  (let ((element (ellama-context-element-webpage-quote :name "test name" :url "https://example.com/" :content "1\n\n2"))
	(ellama-show-quotes nil))
    (should (string-match "\\[test name\\](https://example.com/):\n```emacs-lisp\n(display-buffer \"\\*ellama-quote-.+\\*\")\n```\n" (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-webpage-quote-enabled-markdown ()
  (let ((element (ellama-context-element-webpage-quote :name "test name" :url "https://example.com/" :content "1\n\n2"))
	(ellama-show-quotes t))
    (should (equal "[test name](https://example.com/):
> 1
> 
> 2

"
		   (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-webpage-quote-disabled-org-mode ()
  (let ((element (ellama-context-element-webpage-quote :name "test name" :url "https://example.com/" :content "1\n\n2"))
	(ellama-show-quotes nil))
    (should (string-match "\\[\\[https://example.com/\\]\\[test name\\]\\] \\[\\[elisp:(display-buffer \"\\*ellama-quote-.+\\*\")\\]\\[show\\]\\]" (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-webpage-quote-enabled-org-mode ()
  (let ((element (ellama-context-element-webpage-quote :name "test name" :url "https://example.com/" :content "1\n\n* 2"))
	(ellama-show-quotes t))
    (should (equal "[[https://example.com/][test name]]:
#+BEGIN_QUOTE
1

 * 2
#+END_QUOTE
"
		   (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-info-node-quote-disabled-markdown ()
  (let ((element (ellama-context-element-info-node-quote :name "(emacs)Top" :content "1\n\n2"))
	(ellama-show-quotes nil))
    (should (string-match "```emacs-lisp\n(info \"(emacs)Top\")\n```\nshow:\n```emacs-lisp\n(display-buffer \"\\*ellama-quote-.+\\*\")\n```\n" (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-info-node-quote-enabled-markdown ()
  (let ((element (ellama-context-element-info-node-quote :name "(emacs)Top" :content "1\n\n2"))
	(ellama-show-quotes t))
    (should (equal "```emacs-lisp\n(info \"(emacs)Top\")\n```\n> 1\n> \n> 2\n\n"
		   (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-info-node-quote-disabled-org-mode ()
  (let ((element (ellama-context-element-info-node-quote :name "(emacs)Top" :content "1\n\n2"))
	(ellama-show-quotes nil))
    (should (string-match "\\[\\[(emacs)Top\\]\\[(emacs)Top\\]\\] \\[\\[elisp:(display-buffer \"\\*ellama-quote-.+\\*\")\\]\\[show\\]\\]" (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-info-node-quote-enabled-org-mode ()
  (let ((element (ellama-context-element-info-node-quote :name "(emacs)Top" :content "1\n\n* 2"))
	(ellama-show-quotes t))
    (should (equal "[[(emacs)Top][(emacs)Top]]:\n#+BEGIN_QUOTE\n1\n\n * 2\n#+END_QUOTE\n"
		   (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-file-quote-disabled-markdown ()
  (let ((element (ellama-context-element-file-quote :path "/tmp/test.txt" :content "1\n\n2"))
	(ellama-show-quotes nil))
    (should (string-match "\\[/tmp/test.txt\\](/tmp/test.txt):\n```emacs-lisp\n(display-buffer \"\\*ellama-quote-.+\\*\")" (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-file-quote-enabled-markdown ()
  (let ((element (ellama-context-element-file-quote :path "/tmp/test.txt" :content "1\n\n2"))
	(ellama-show-quotes t))
    (should (equal "[/tmp/test.txt](/tmp/test.txt):
> 1
> 
> 2

"
		   (ellama-context-element-format element 'markdown-mode)))))

(ert-deftest test-ellama-context-element-format-file-quote-disabled-org-mode ()
  (let ((element (ellama-context-element-file-quote :path "/tmp/test.txt" :content "1\n\n2"))
	(ellama-show-quotes nil))
    (should (string-match "\\[\\[/tmp/test.txt\\]\\[/tmp/test.txt\\]\\] \\[\\[elisp:(display-buffer \"\\*ellama-quote-.+\\*\")\\]\\[show\\]\\]" (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-format-file-quote-enabled-org-mode ()
  (let ((element (ellama-context-element-file-quote :path "/tmp/test.txt" :content "1\n\n* 2"))
	(ellama-show-quotes t))
    (should (equal "[[/tmp/test.txt][/tmp/test.txt]]:
#+BEGIN_QUOTE
1

 * 2
#+END_QUOTE
"
		   (ellama-context-element-format element 'org-mode)))))

(ert-deftest test-ellama-context-element-extract-buffer ()
  (with-temp-buffer
    (insert "123")
    (let ((element (ellama-context-element-buffer :name (buffer-name))))
      (should (equal "123" (ellama-context-element-extract element))))))

(ert-deftest test-ellama-context-element-extract-file ()
  (let* ((filename (expand-file-name "LICENSE" (locate-dominating-file "." ".git")))
         (element (ellama-context-element-file :name filename)))
    (should (string-match "GNU GENERAL PUBLIC LICENSE"
                          (ellama-context-element-extract element)))))

(ert-deftest test-ellama-context-element-extract-info-node ()
  (let ((element (ellama-context-element-info-node :name "(dir)Top")))
    (should (string-match "This" (ellama-context-element-extract element)))))

(ert-deftest test-ellama-context-element-extract-text ()
  (let ((element (ellama-context-element-text :content "123")))
    (should (string-match "123" (ellama-context-element-extract element)))))

(ert-deftest test-ellama-context-element-extract-webpage-quote ()
  (let ((element (ellama-context-element-webpage-quote :content "123")))
    (should (equal "123" (ellama-context-element-extract element)))))

(ert-deftest test-ellama-context-element-extract-info-node-quote ()
  (let ((element (ellama-context-element-info-node-quote :content "123")))
    (should (equal "123" (ellama-context-element-extract element)))))

(ert-deftest test-ellama-context-element-extract-file-quote ()
  (let ((element (ellama-context-element-file-quote :content "123")))
    (should (equal "123" (ellama-context-element-extract element)))))

(ert-deftest test-ellama-context-element-display-buffer ()
  (with-temp-buffer
    (let ((element (ellama-context-element-buffer :name (buffer-name))))
      (should (equal (buffer-name) (ellama-context-element-display element))))))

(ert-deftest test-ellama-context-element-display-file ()
  (let* ((filename (expand-file-name "LICENSE" (locate-dominating-file "." ".git")))
         (element (ellama-context-element-file :name filename)))
    (should (equal (file-name-nondirectory filename) (ellama-context-element-display element)))))

(ert-deftest test-ellama-context-element-display-info-node ()
  (let ((element (ellama-context-element-info-node :name "(dir)Top")))
    (should (equal "(info \"(dir)Top\")" (ellama-context-element-display element)))))

(ert-deftest test-ellama-context-element-display-text ()
  (let ((element (ellama-context-element-text :content "123")))
    (should (equal "\"123...\"" (ellama-context-element-display element)))))

(ert-deftest test-ellama-context-element-display-webpage-quote ()
  (let ((element (ellama-context-element-webpage-quote :name "Example" :url "http://example.com" :content "123")))
    (should (equal "Example" (ellama-context-element-display element)))))

(ert-deftest test-ellama-context-element-display-info-node-quote ()
  (let ((element (ellama-context-element-info-node-quote :name "Example" :content "123")))
    (should (equal "(info \"Example\")" (ellama-context-element-display element)))))

(ert-deftest test-ellama-context-element-display-file-quote ()
  (let ((element (ellama-context-element-file-quote :path "/path/to/file" :content "123")))
    (should (equal "file" (ellama-context-element-display element)))))

(ert-deftest test-ellama-context-element-extract-buffer-quote ()
  (with-temp-buffer
    (insert "123")
    (let ((element (ellama-context-element-buffer-quote :name (buffer-name) :content "123")))
      (should (equal "123" (ellama-context-element-extract element))))))

(ert-deftest test-ellama-context-element-display-buffer-quote ()
  (with-temp-buffer
    (let ((element (ellama-context-element-buffer-quote :name (buffer-name) :content "123")))
      (should (equal (buffer-name) (ellama-context-element-display element))))))

(ert-deftest test-ellama-md-to-org-code-simple ()
  (let ((result (ellama--translate-markdown-to-org-filter "Here is your TikZ code for a blue rectangle:
```tex
\\documentclass{article}
\\usepackage{tikz} \\begin{document}
\\begin{tikzpicture} \\node[rectangle, draw=blue] (mynode) {Text};
\\end{tikzpicture}
\\end{document}
```
This code will create a rectangle with a blue border and light
blue filling. You can replace \'Text\' with your desired text
or other TikZ elements.")))
    (should (string-equal result "Here is your TikZ code for a blue rectangle:
#+BEGIN_SRC tex
\\documentclass{article}
\\usepackage{tikz} \\begin{document}
\\begin{tikzpicture} \\node[rectangle, draw=blue] (mynode) {Text};
\\end{tikzpicture}
\\end{document}
#+END_SRC
This code will create a rectangle with a blue border and light
blue filling. You can replace \'Text\' with your desired text
or other TikZ elements."))))

(ert-deftest test-ellama-md-to-org-code-hard ()
  (let ((result (ellama--translate-markdown-to-org-filter "Here is your TikZ code for a blue rectangle:
```
\\documentclass{article}
\\usepackage{tikz} \\begin{document}
\\begin{tikzpicture} \\node[rectangle, draw=blue] (mynode) {Text};
\\end{tikzpicture}
\\end{document}
```
This code will create a rectangle with a blue border and light
blue filling. You can replace \'Text\' with your desired text or other
TikZ elements.")))
    (should (string-equal result "Here is your TikZ code for a blue rectangle:
#+BEGIN_SRC
\\documentclass{article}
\\usepackage{tikz} \\begin{document}
\\begin{tikzpicture} \\node[rectangle, draw=blue] (mynode) {Text};
\\end{tikzpicture}
\\end{document}
#+END_SRC
This code will create a rectangle with a blue border and light
blue filling. You can replace \'Text\' with your desired text or other
TikZ elements."))))

(ert-deftest test-ellama-md-to-org-code-nightmare ()
  (let ((result (ellama--translate-markdown-to-org-filter "Here is your TikZ code for a blue rectangle:
```
\\documentclass{article}
\\usepackage{tikz} \\begin{document}
\\begin{tikzpicture} \\node[rectangle, draw=blue] (mynode) {Text};
\\end{tikzpicture}
\\end{document}```This code will create a rectangle with a blue border and light
blue filling. You can replace \'Text\' with your desired text
or other TikZ elements.")))
    (should (string-equal result "Here is your TikZ code for a blue rectangle:
#+BEGIN_SRC
\\documentclass{article}
\\usepackage{tikz} \\begin{document}
\\begin{tikzpicture} \\node[rectangle, draw=blue] (mynode) {Text};
\\end{tikzpicture}
\\end{document}
#+END_SRC
This code will create a rectangle with a blue border and light
blue filling. You can replace \'Text\' with your desired text
or other TikZ elements."))))

(ert-deftest test-ellama-md-to-org-code-multiple-bad-blocks ()
  (let ((result (ellama--translate-markdown-to-org-filter "Some text:
```
First block
```
other text:
```
Second block
```
more text:
```
third block
```
That's it.")))
    (should (string-equal result "Some text:
#+BEGIN_SRC
First block
#+END_SRC
other text:
#+BEGIN_SRC
Second block
#+END_SRC
more text:
#+BEGIN_SRC
third block
#+END_SRC
That's it."))))

(ert-deftest test-ellama-md-to-org-code-inline-latex ()
  (let ((result (ellama--translate-markdown-to-org-filter "_some italic_
$$P_\\theta(Y_T, ..., Y_2|Y_1, x_1, ..., x_T)$$
_more italic_
$P_\\theta$
_more italic_")))
    (should (string-equal result "/some italic/
$$P_\\theta(Y_T, ..., Y_2|Y_1, x_1, ..., x_T)$$
/more italic/
$P_\\theta$
/more italic/"))))


(ert-deftest test-ellama-md-to-org-code-inline-latex-with-code ()
  (let ((result (ellama--translate-markdown-to-org-filter "_some italic_
$$P_\\theta(Y_T, ..., Y_2|Y_1, x_1, ..., x_T)$$
_more italic_
```emacs-lisp
(msg \"ok\")
```
$P_\\theta$
_more italic_")))
    (should (string-equal result "/some italic/
$$P_\\theta(Y_T, ..., Y_2|Y_1, x_1, ..., x_T)$$
/more italic/
#+BEGIN_SRC emacs-lisp
(msg \"ok\")
#+END_SRC
$P_\\theta$
/more italic/"))))

(ert-deftest test-ellama-replace-outside-of-code-blocks-minimal ()
  (let ((result (ellama--replace-outside-of-code-blocks "This")))
    (should (string-equal result "This"))))

(ert-deftest test-ellama-md-to-org-code-snake-case ()
  (let* ((fill-column 70)
	 (result (ellama--translate-markdown-to-org-filter "```python
# Example of snake case variables and functions

# Variable names using snake_case
student_name = \"Alice Johnson\"
class_name = \"Mathematics\"
grade_level = 10

# Function name using snake_case
def calculate_average_score(math_score, science_score, english_score):
    average_score = (math_score + science_score + english_score) / 3
    return average_score

# Using the function
student_math_score = 85
student_science_score = 90
student_english_score = 78

average_score = calculate_average_score(student_math_score, student_science_score, student_english_score)
print(f\"The average score of {student_name} in {class_name} is: {average_score:.2f}\")
```

In this example:
- Variable names like `student_name`, `class_name`, and `grade_level` use snake_case.
- The function name `calculate_average_score` also follows the snake_case convention.

Snake case helps improve readability, especially in languages that are sensitive to capitalization like Python.")))
    (should (string-equal result "#+BEGIN_SRC python\n# Example of snake case variables and functions\n\n# Variable names using snake_case\nstudent_name = \"Alice Johnson\"\nclass_name = \"Mathematics\"\ngrade_level = 10\n\n# Function name using snake_case\ndef calculate_average_score(math_score, science_score, english_score):\n    average_score = (math_score + science_score + english_score) / 3\n    return average_score\n\n# Using the function\nstudent_math_score = 85\nstudent_science_score = 90\nstudent_english_score = 78\n\naverage_score = calculate_average_score(student_math_score, student_science_score, student_english_score)\nprint(f\"The average score of {student_name} in {class_name} is: {average_score:.2f}\")\n#+END_SRC\n\nIn this example:\n- Variable names like ~student_name~, ~class_name~, and ~grade_level~\n  use snake_case.\n- The function name ~calculate_average_score~ also follows the\n  snake_case convention.\n\nSnake case helps improve readability, especially in languages that are\nsensitive to capitalization like Python."))))

(ert-deftest test-ellama--fix-file-name ()
  (should (string=
	   (ellama--fix-file-name "a/\\?%*:|\"<>.;=")
	   "a_____________")))

(ert-deftest test-ellama-md-to-org-code-inline-code ()
  (let ((result (ellama--translate-markdown-to-org-filter "_some italic_
`some_snake_case`
_more italic_
```emacs-lisp
(msg \"ok\")
```
$P_\\theta$
_more italic_")))
    (should (string-equal result "/some italic/
~some_snake_case~
/more italic/
#+BEGIN_SRC emacs-lisp
(msg \"ok\")
#+END_SRC
$P_\\theta$
/more italic/"))))

(ert-deftest test-ellama-md-to-org-inline-code ()
  (let* ((fill-column 80)
         (result (ellama--translate-markdown-to-org-filter "```go
package main
```
### Explanation:
1. **Initialization**: We create a boolean slice `prime` of size `n+1`, where each
index represents whether the number is prime (`true`) or not (`false`).")))
    (should (string= result "#+BEGIN_SRC go
package main
#+END_SRC
*** Explanation:
1. *Initialization*: We create a boolean slice ~prime~ of size ~n+1~, where each
index represents whether the number is prime (~true~) or not (~false~)."))))

(ert-deftest test-ellama-md-to-org-lists ()
  (let* ((fill-column 80)
         (result (ellama--translate-markdown-to-org-filter "<think>Okay, the user asked me to create a list of fruits. Let me think about how to approach this.</think> Here’s a comprehensive list of fruits, categorized for clarity:

---

### **Common Fruits**
1. **Apple**
2. **Banana**
3. **Orange**
4. **Grape**
5. **Strawberry**
6. **Blueberry**

---

### **Additional Notes**
- **Tomatoes** are technically fruits (part of the nightshade family).
- **Coconut** is a tropical fruit, often used in cooking.
- **Papaya** is a versatile fruit with nutritional value.

Let me know if you'd like a simplified version or a specific category (e.g., by region, season, or type)! 🍎🍊")))
    (should (string= result "#+BEGIN_QUOTE
Okay, the user asked me to create a list of fruits. Let me think about how to
approach this.
#+END_QUOTE
 Here’s a comprehensive list of fruits, categorized for clarity:

---

*** *Common Fruits*
1. *Apple*
2. *Banana*
3. *Orange*
4. *Grape*
5. *Strawberry*
6. *Blueberry*

---

*** *Additional Notes*
- *Tomatoes* are technically fruits (part of the nightshade family).
- *Coconut* is a tropical fruit, often used in cooking.
- *Papaya* is a versatile fruit with nutritional value.

Let me know if you'd like a simplified version or a specific category (e.g., by
region, season, or type)! 🍎🍊"))))

(defun ellama-test-max-common-prefix ()
  "Test the `ellama-max-common-prefix` function."
  (should (equal (ellama-max-common-prefix "" "") ""))
  (should (equal (ellama-max-common-prefix "abc" "abcd") "abc"))
  (should (equal (ellama-max-common-prefix "abcd" "abc") "abc"))
  (should (equal (ellama-max-common-prefix "abcdef" "abcefg") "abc"))
  (should (equal (ellama-max-common-prefix "a" "b") ""))
  (should (equal (ellama-max-common-prefix "a" "") ""))
  (should (equal (ellama-max-common-prefix "" "b") "")))

(ert-deftest ellama-test-max-common-prefix ()
  "Run the tests for `ellama-max-common-prefix`."
  (ellama-test-max-common-prefix))

(ert-deftest ellama--string-without-last-line-test ()
  "Test `ellama--string-without-last-line` function."
  (should (equal (ellama--string-without-last-line "Line1\nLine2\nLine3")
                 "Line1\nLine2"))
  (should (equal (ellama--string-without-last-line "SingleLine")
                 ""))
  (should (equal (ellama--string-without-last-line "")
                 ""))
  (should (equal (ellama--string-without-last-line "Line1\nLine2")
                 "Line1")))

(provide 'test-ellama)

;;; test-ellama.el ends here
