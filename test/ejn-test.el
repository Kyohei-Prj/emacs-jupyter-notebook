;;; ejn-test.el --- Tests for EJN  -*- lexical-binding: t -*-

;; Copyright (C) 2025  EJN Contributors

;; Author: EJN Contributors
;; Version: 0.1.0
;; Keywords: jupyter, notebook, emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Test suite for Emacs Jupyter Notebook - scaffolding only.

;;; Code:

(require 'buttercup)
(require 'ejn)

;; Empty test suite - Phase 1 scaffolding only.

(describe "EJN"
  (it "loads without error"
    (expect 't :to-be-truthy)))

;;; ejn-test.el ends here
