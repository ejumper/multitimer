# Bottom Bar Menu

The bottom bar menu is where other actions will be accessed (from left to right)
- Settings
- Calendar
- Tasks
- Templates
- New Event (dated interval)
Each item (besides settings) has a "quick action" triggered by right clicking / long pressing instead of tapping.
- Calendar: opens to the "non-default" view (if month view is default it opens to week and vice versa
- Tasks: Goes straight to Creating a new tasks timer
- Templates: Saves the currently open timer as a template

The bottom bar is just a pill shaped semitransparent background with an outline and the icons evenly spaced out across it.

Each page that these bottom bars buttons takes you to has its own custom bottom bar which will be described in it's section.

## Settings

### New events (dated intervals) override default timer by default
- toggling this on simply means that when the new events button is pressed, the "Overwrite Default Timer" toggle is on by default

### Home
define what "home" is...
- By default its the current days Timer
- It can be changed to a specific Task Timer

### Interval Options defaults

Set whether auto-finish, duration and time are toggled on/off by default.

### Bottom Bar
- home
(only bottom bar option for now. In future versions where there are more settings to organize, there will be settings categories here, but for now only home)

## Calendar view

button in the bottom bar
- clicking it sends you to the calendar page
	- on the calendar page, it shows the default calendar view (current week by default, set it to month in the settings)
		- essentially just a list of the days of the week and maybe something like the number of intervals on that day's timer
			```
			[Monday			3]
			[Tuesday		5]
			[Wednesday		2]
			[Thursday		7]
			[Friday			8]
			[Saturday		3]
			[Sunday			1]
			```
			- The current day is highlighted by default, if the day is changed in the text boxes described below, that day becomes highlighted
		```
		[🗓️] [08] [13] [26]
		```
	- If you then tap on a day, it will open that day's board
- swiping left/right here goes to the next/previous month/week

### Bottom Bar (from left to right)
- home
- view toggle (toggles between week and month view
- date setter (opens a pop-up menu (think similar to the html calendar) to change the date shown (iffy on what this should actually look like, open to ideas)

## Tasks

This is essentially a more traditional "task manager" built into the app. This should essentially be a very simplified clone of apple reminders, simply restyled to match this apps UI...

opens to a list of the task lists
- each list is styled like the intervals in the timer editor (title in top left, duration in top right is replaced by number of tasks in the list, no alarm title in the bottom left obviously)
- drag to reorder lists (same as is done with intervals)
- long press to rename list (edit inline
- select to open the task list

in the task list (the task list UI looks *very* similar to the timer editor)
- the tasks look almost identical to the intervals in the timer editor
	- title in the top left, no duration in the top right obviously, alarm title is replaced by an optional description
- tap to edit task title, right click to edit description
- the circle check to the left of the interval in the timer editor becomes how you toggle the item completed
- they can be dragged to be reordered
- the list title is at the top
- when checked complete there's a 3 second delay (to uncheck if checked by accident) and then it goes to the bottom below the checked items (there's a button to toggle these visible/invisible)

This is intentionally simple in v2, things like subtasks will come later.

### Bottom Bar

list of task lists bottom bar
- home
- new list (creates a new list entry at the top and asks for its name)
- delete list (hit this > tap the list you want to delete > confirm deletion)

task list bottom bar
- back to list of task lists
- new task
- delete delete task (hit this > tap the list you want to delete > confirm deletion)
- toggle completed items visible/invisible

## Timer Templates

The idea here is simple, Timers can be saved to templates. When a timer is saved to a template, it is saved and shown in a list 
- the list is styled after how intervals look in the editor...
	- timer name in the top left, total duration of the timer in the top right, dated created/modified  in the bottom left (replacing the notification sound)
When its selected, it opens in a "temp" board, not associated with a day or a list. It can be run from there, or it can be given various rules...
- Make that timer the default timer (days with no other timer configured are given this timer)
- Make the timer the default timer on certain conditions (make the timer the default timer for certain days of the week or make the timer the default timer for certain days of the month) (either overrides the default timer, days of the month overrides days of the week)

### Bottom Bar

On the template list page
- home
- toggle between listing alphabetically and by last modified
- reverse the list order
- create a new timer template
- create a new list template

On a temp board
- home
- back (sends you back to the templates list
- make the timer the default timer (with confirmation pop up)
- make the timer the default timer for a given day of the week
	- shows the calendar view, select the day its the default for, has a toggle repeat (same day every week)
- make the timer the default timer for a given day of the month
	- shows the calendar view, select the day its the default for, has a toggle repeat (same day every month)

## New Events

This opens the interval editor, with "dated" toggled on. The user fills out the interval as normal. The only difference is that there are 2 new options added between the interval title text box and the options toggles: "Date" (with dd mm yy text boxes), to fill in the date it occurs on and a new first options toggle "Overwrite Default Timer" toggled off by default (unless the setting is changed) which decides whether the event will be added as a new first interval to the default timer (if one is set), or replace the default timer for the day its added on with the new single interval timer.
- this does not apply to other events that have been added to that day, for instance if this is the 3rd event being added to the day, that naturally resolves itself as long as the times don't overlap. If they do overlap, for now show an error message and don't let them add the interval until they use a non-overlapping time.

# Other Additions

## Swiping left/right on the current days timer takes you to the next/previous day

self explainitory, only applies when a date's board is being shown.

## Dated Intervals and Intervals with no duration (see notes for details on how these work)

create intervals that happen at an exact time. 
- in the interval editor, below Auto-finish are 2 new toggles: Duration and Time
- Currently the duration editor is always shown, because intervals must always have durations. in v2, it will only be shown (beneath the duration toggle) when duration is toggled on
- same for time, when time is toggled on, it becomes a "dated" duration and shows a "time setter", identical to the duration setter, but showing the time instead of the duration at the bottom (set in 24hr time to avoid having to place am/pm)

## Interval Completion (see notes for details on how these work)

When an interval finishes , instead of "continue", its either completed or not completed. If not completed, there's some sort of way to redo the non-completed items at the end, where the timer can rerun, with only the non-completed items, needs some thought.
- auto-finish intervals are also auto-completed
