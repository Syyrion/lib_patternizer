## New Instructions

`raise`
Duplicates a value from the stack at any depth.

`clone`
Duplicates the entire stack.

`size`
Returns how tall the stack is.

## Better syntax for calling Lua functions

`call:` kinda sucks. We can do better.

A new function `Patternizer:include(name, fn)`
Adds a new lua function to a patternizer instance which can later be called by any Stackup run by that specific instance. The name cannot conflict with already
existing keywords.

Calls a previously included function.
```
1 2 (1 2 3 4)foo
```

A character surrounded by single quotes calls a function associated with a character used in P-strings.
```
1 2 (1 2 3 4)'f'
```

The parentheses tell each function how many values to pop.

Nesting function calls is allowed:
```
1 2 (1 2 (3 1)bar 4)foo
```
Also, once an opening parethesis is encountered, everything in the stack below it is not allowed to be modified. They can still be duplicated though.

Also, you're not allowed to do weird things like this:
```
3 (for 1)foo

end
```
Enclosing keywords/symbols must remain balanced.

Functions can be put on the timeline by using `#()`
```
1 2 #(1 2 3 4)foo
```
All return values of foo are discarded.

## More P-string functionality (Experimental)

Strings are now allowed on the stack and are surrounded by double quotes
```
"_.+_." p "|.-" p
```

## Else-if statements

Turns this:
```
<condition1> if
    <body1>
else
    <condition2> if
        <body2>
    else
        <condition3> if
            <body3>
        else
            <body4>
        end
    end
end
```

Into this:
```
<condition1> if

else <condition2> if

else <condition3> if

else <condition4> if

endif
```

`endif` will close as many else statements as possible. At least one if statement must be closed.
It's use is entirely optional though be warned that it is greedy so it's all or nothing.

This does not work:
```
<condition1> if
    <body1>
else
    <condition2> if
        <body2>
    else <condition3> if
        <body3>
    else
        <body4>
    endif
end
```
