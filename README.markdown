# Jigger.sugar

Jigger.sugar adds an action to easily manipulate numbers and colors in [Espresso](http://macrabbit.com/espresso/). After installing it, use the shortcut `command =` to edit the number or CSS hex code under your cursor. If you have one or more selections when you use `command =`, all selected numbers and/or colors will be updated. If you have neither a color nor a number under your cursor, one will be inserted.

**Calculations**

* When modifying multiple numbers simultaneously, click the arrow next to the "number" token to see all numbers that will be affected by your calculation
* If you append prefixes to your numbers, the last prefix in the calculation will be used (`12px/16em` = 0.75em)
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

**Colors**

* If you are editing multiple colors, only the first one will be shown in the GUI but all of them will be changed to whatever color you select
* Only CSS hex colors are currently supported
* By default hex colors will insert their three character variant, if possible (so `#fff` instead of `#ffffff`) and use lowercase letters. You can modify the formatting in the advanced preferences (Espresso&rarr;Preferences).

## Installation

**Requires Espresso 2.0**

1. [Download Jigger.sugar](https://github.com/downloads/onecrayon/Jigger-sugar/Jigger.sugar.zip)
2. Unzip the downloaded file (if your browser doesn't do it for you)
3. Double click the Jigger.sugar file to install it

You **cannot** install this Sugar by cloning the git repository or using the "zip" button at the top of this page, because it is written in Objective-C and has to be compiled.

## MIT License

Copyright (c) 2012 Ian Beck

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
