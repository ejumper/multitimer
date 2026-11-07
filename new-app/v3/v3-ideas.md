# v3 Ideas

## List View

This simply replaces the timer by showing something essentially identical to what the interval section of the Timer editor shows. 
- Instead of showing the stopwatch, there is a view with the list of intervals (including groupings) just like you see in the timer editor (except no selector circle)
- The intervals start out with no background and the background fills in from left to right as the timer elapses.
- For groups with repeats, it fills in its background with each repeat from top to bottom and the repeat number goes down to show the number of repeats left
- just like in the timer editor, an intervals duration is placed in the top left. In List View, that time counts down as the duration elapses, but here it shows <time left>/<total time>, i.e., "10m5s/15m"
- when an interval is completed, it becomes semi-transparent, just like the ticks in the stopwatch do when they have passed
- The current interval is as close to center as possible by default (only applies when there's overflow)
	- for instance the first interval won't be centered, it will be at the top, the last interval will never be centered, it will be at the bottom), so the scroll position sets to place you as close to the center as possible, so that the currently active interval is always in view. So the closest the top interval can get to the center is scrolled all the way up, if there are only 3 intervals, there might not be any overflow, so there is nowhere to move the scroll position to get items closer to the center.
	- When scrolling, the currently active interval is "magnetized" at the center position, think of this like snapping in photoshop. As the active interval gets close to the "closest it can get to the center" position, scrolling speed slows slightly and when it is at its "closest to the center position", there is a small deadspot in the scroll (just like snapping) so its easier to get it recentered
	- when an interval finishes, it autoscrolls to its "closest to the center position" if its not already in it. When the next interval begins, it autoscrolls to place that interval in its "closest to the center position"
- when an interval is finished (and its not auto-finish), the time in the top left is replaced with "wait" and the border on the timer pulses (just like the "» tap to continue" notification does)

## Calendar/Timer Data

I want to change how Calendar/Timer Data is saved. The idea is that timers can easily be created, edited, etc., in place text markdown files. An interval is simply a line in a .md file with specific syntax. A file following the format can be placed in a configured templates folder to add to the list of templates. The syntax is very simple...
- At the top is the Timer Name as a h1
- Below that, intervals are everything within brackets. 
- Each parameter has a character that defines what it is followed by text within parenthesis
	- The interval name sits at the start of the line and is everything before the brackets start
	- /( ) = the interval color, accepts any common css color formatting (hex, rgb, hsl, etc.)
	- #( ) = the interval duration
	- @( ) = the interval time (for dated intervals)
	- !( ) = the alert to play when the interval ends
	- & = only the symbol is needed, means the interval auto-finishes
```
# <Timer Name>
<Interval Name> [/(<color>) #(<Duration>) @(<hh:mm:ss>) !(<alert-file-name>) &(auto-finish)]
```
- order doesn't matter, it simply parses from the formatting
- if anything is not used, that is valid and just as useful for defining the interval as having it: no alert, the interval has no alert. no duration the interval has no duration, etc.

## .cal file compatibility


### Bottom bar
setting to reorder the buttons in the bottom bar
