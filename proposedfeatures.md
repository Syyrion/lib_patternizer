# Potential Features

## Macros/functions

```
#define foo
    <body>
#endef
```

## Variable argument syntax

```
1 2 { 1 2 3 4 }
```

## More P-string functionality

- Repeating divisions

## Else-if statements

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


<condition1> if

else <condition2> if

else <condition3> if

else <condition4> if

fi
```

For this to work, fi will have to look into the future instructions.

`fi` will close one if or else statement as it's first action, then it will close as many else statements as possible until the stack is empty or something other than else is encountered.