**Patternizer v0.17**

# Operations

## Math

For non-communative operations, the operation is performed on the second popped number using the first (`a b -` is `a - b`).

* `1 2 3 4`  
  Any number pushes that number to the stack.

* `+`  
  Adds two numbers
* `-`  
  Subtracts two numbers.

* `*`  
  Multiplies two numbers.

* `/`  
  Divides two numbers.

* `%`  
  Takes the mod of two numbers.

* `floor`  
  Floor.

* `ceil`  
  Ceiling.

* `rnd`  
  Picks a random integer within a range. Both inputs must be integers. The number popped first is the upper bound and the second is the lower bound.

* `abs`  
  Absolute value.


## Stack Operations

Before and after snapshots of the stack are shown as `( <before> - <after> )`

* `dup`  
  Duplicates the top value of the stack.  
  `( a - a a )`

* `drop`  
  Deletes the top value of the stack.  
  `( a - )`

* `swap`  
  Swaps the top two values of the stack.  
  `( a b - b a )`

* `over`  
  Duplicates the value under the value on top of the stack and pushes it to the stack.  
  `( a b - a b a )`

* `roll`  
  Pops two values. The second is the depth and the first is the amount of times to roll the stack. A negative depth value will start indexing from the bottom of the stack. A negative repeat value will roll the stack in the opposite direction.  
  `( a b c d 4 1 - b c d a )`  
  `( a b c d 4 2 - c d a b )`  
  `( a b c d 4 3 - d a b c )`  
  `( a b c d 4 -1 - d a b c )`  
  `( a b c d 3 1 - a c d b )`

## Logic

Logic operators push 1 if true, 0 if false. If a number is not 0 it is considered as true.


* `==`  
  Equality.

* `!=`  
  Equality.

* `>`  
  Greater than.

* `>=`  
  Greater than or equal to.

* `<`  
  Less than.

* `<=`  
  Less than or equal to.

* `or`  
  Logical or.

* `and`  
  Logical and.

* `not`  
  Logical not.
  

## Control flow

* `while <statements> end`  
  Pops a value off the stack. If it's false, skip to the instruction after `end`, otherwise run the statements. When the statements are done, pop another value and perform a check and repeat as described. (This can be used to flush the stack until a 0 is reached.)

* `for <statements> end`  
  Same as above but whenever a check is made, the value on top of the stack is duplicated before being popped. When the loop ends, the value on top of the stack is dropped.

* `if <statements> end`  
  Pops a value. If it's true, the statements are run.

* `if <statements> else <statements> end`  
  Pops a value. If it's true, the statements within the first set is run, otherwise the second set is run.

* `return`
  Stops the program. The stack is the output.

## Variables

### Read only

These variables are automatically initialized and cannot be changed.

* `$sides`  
  Pushes the current side count to the stack.

* `$hsides`  
  Pushes the current side count divided by 2 (unrounded).

* `$th`  
  Pushes 40 to the stack.

* `$idealth`  
  Pushes the ideal thickness to the stack.

* `$idealdl`  
  Pushes the ideal delay to the stack.

* `$sperpr`  
  Pushes the seconds per player rotation.


### Process

These variables are automatically initialized but can be modified.

* `$abs`  
  Pushes the absolute pivot to the stack. Initialized to a random side [0, `$sides`).

* `=abs`  
  Sets the absolute pivot. This usually isn't recommended to do in the middle of a script as this variable serves as an anchor point for most other calculations.

* `$rel`  
  Pushes the relative pivot to the stack. Initialized to 0.

* `=rel`  
  Sets the relative pivot. Beware as this ignores the mirror variable so using this may cause unexpected results. Use `rmv` instead.

* `$rof`  
  Pushes the relative offset to the stack. Initialized to 0.

* `=rof`  
  Sets the relative offset.

* `$mirror`  
  Pushes the mirror value to the stack (either 1 or -1). Initialised to 1 or -1.

* `=mirror`  
  Pops the top value. If it's false, `$mirror` is set to 1, otherwise -1.

* `$tolerance`  
  Pushes the tolerance to the stack. Initialized to 4.

* `=tolerance`  
  Sets the tolerance. This is usually a small value to prevent seams from forming in patterns. 

## Functions

### Positioning

* `rmv`  
  Pops the top value of the stack and moves the relative pivot by that amount. Also updates the relative offset. This is the preferred method to modify the relative pivot.  

  Equivalent to:
  
  ```
  dup abs dup $sides $hsides 3 1 roll

  < if swap -
  else drop
  end

  =rof $mirror * $rel + $sides %
  ```

* `a`  
  Pushes the absolute position (for consistency).  

  Equivalent to:

  ```
  $abs
  ```

* `r`  
  Pushes the true relative position.  
  
  Equivalent to:

  ```
  $abs $rel + $sides %
  ```

### Thickness

* `i`  
  Converts units of ideal thickness to absolute thickness.  

  Equivalent to
  
  ```
  $idealth *
  ```

* `spath`  
  Pushes the short path thickness.  
  
  Equivalent to:
  ```
  $rof i
  ```
  
* `lpath`  
  Pushes the long path thickness.  
  
  Equivalent to:
  ```
  $sides $rof - i
  ```

* `th2s`  
  Converts an absolute thickness value to seconds.
  
* `s2th`  
  Converts a seconds value to absolute thickness.

## Timeline

* `h:<pattern>`  
  Pops the top two numbers on the stack. The first number is the position; the second is the absolute thickness. Adds a wall creation event to the timeline. This function does not add the tolerance value to the thickness.
  
* `sleep`  
  Accepts a duration in seconds and adds a wait event to the timeline.

* `thsleep`  
  Accepts a thickness and waits the coresponding amount of seconds.  

  Equivalent to:

  ```
  th2s sleep
  ```

* `rsleep`  
  Waits the amount of time it would take for the player to rotate a certain number of revolutions.
  
  Equivalent to:
  ```
  $sperpr * sleep
  ```

* `p:<pattern>`  
  The combination of `h:<pattern>` and `thsleep`. Generally the default choice for generating walls.
  

* `call:<char>`  
  Creates a function event for the first character after the colon. First a number is popped to indicate how many arguments the function should recieve. Then that many numbers are popped and saved for later use with the function call. Arguments are passed to the function in the reverse order in which they were popped. (i.e. the first popped number is the last argument and vice versa.)