# Jigger.sugar

Jigger.sugar allows you to easily manipulate numbers, colors, and file URLs in [Espresso](http://macrabbit.com/espresso/). After installing, use the shortcut `command =` to edit the number, CSS hex code, or file path under your cursor. If Jigger does not recognize what is under your cursor, you will have the option to insert either number or a color.

When modifying a single color or number, you have the option to modify all instances of that color or number across the entire file; this can be very useful for managing a CSS color palette, for instance.

## Installation

**Requires Espresso 2.0** and **OS X 10.9**

1. [Download Jigger.sugar](https://github.com/onecrayon/Jigger-sugar/releases/download/v2.0/Jigger.sugar.zip)
2. Unzip the downloaded file (if your browser doesn't do it for you)
3. Double click the Jigger.sugar file to install it

**Still on 10.7 or 10.8?** You can still [download Jigger 1.0](https://github.com/onecrayon/Jigger-sugar/releases/download/v1.0/Jigger.sugar.zip), but it has a shortcut conflict with Seesaw.sugar and does not support browsing for files. Unfortunately, I had to require 10.9 for Jigger 2.0 because the calculation logic it depends on will not compile for older OS versions.

You **cannot** install this Sugar by cloning the git repository or using the "zip" button at the top of this page, because it is written in Objective-C and has to be compiled.

## Usage notes

### Calculations

* When modifying multiple numbers within a selection, click the arrow next to the "number" token to see all numbers that will be affected by your calculation
* If you append suffixes to your numbers, the last suffix in the calculation will be used (`12px/16em` = 0.75em)
* Currency calculations currently only support USD and round to the nearest cent (`$3.99/4` = $1.00)
* You can use the following operators: add (`2+2` = 4), subtract (`2-2` = 0), multiply (`2*2` = 4), divide (`2/2` = 1), factorial (`4!` = 24), exponentiation (`2**3` = 8), and percentages (`2+20%` = 2.4)
* You can also use the following functions: 
    * `sqrt()` - returns the square root of the passed parameter
    * `log()` - returns the base 10 log of the passed parameter
    * `ln()` - returns the base e log of the passed parameter
    * `log2()` - returns the base 2 log of the passed parameter
    * `exp()` - returns e raised to the power of the passed parameter
    * `ceil()` - returns the passed parameter rounded up
    * `floor()` - returns the passed parameter rounded down

Calculations also support other lesser-used [operators](https://github.com/davedelong/DDMathParser/wiki/Operators) and [functions](https://github.com/davedelong/DDMathParser/wiki/Built-in-Functions).

### Colors

* If you are editing multiple colors within a selection, only the first will be shown in the GUI but all of them will be changed to whatever color you select
* Only CSS hex colors are currently supported
* By default hex colors will insert their three character variant, if possible (so `#fff` instead of `#ffffff`) and use lowercase letters. You can modify the formatting in the advanced preferences (Espresso&rarr;Preferences).
* The OS X color picker is problematic because it will report one color but display another in the preview swatch. For instance, if you use the Web Safe Color palette and choose `#333333` the preview swatch at the top of the picker will actually display `#424242`. By default Jigger.sugar will output `#333` (the reported color), but if it is important to you that the color code matches the displayed color, you can change this behavior when you choose the color.

## Changelog

**2.0** (now requires OS 10.9)

* New GUI for calculations and choosing colors to make it more explicit that you can only do one at a time
* New support for modifying file URLs in HTML or CSS using the system file browser, including support for root-relative links
* Changing all copies of a color or number within the file is now an option within the GUI, rather than a separate action; you only have to remember one shortcut! (Fixes the shortcut conflict between Jigger.sugar and Seesaw.sugar)
* Migrated CSS swatch vs. reported color preference into the main GUI, to allow you to see exactly what it does
* Calculations GUI now offers tips on supported common operators and functions, and a help button linking to the DDMathParser wiki

**v1.0**

* Initial release!
* Supports modifying numbers with calculations, or colors with the built-in OS X color picker

## MIT License

Copyright (c) 2012-2014 Ian Beck

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
