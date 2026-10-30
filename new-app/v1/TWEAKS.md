1. when the timer editor and the interval editor are opened, I'd like to have the name editor in focus by default.

2. There's a bug with the interval editor where when I bring focus to it with tab, I have to then hit enter to edit the name, and then I can't move focus away from it with tab or go back with escape until I click somewhere on the screen. This is not an issue with the timer editor, that makes the text editable when the focus is on it and I can use tab and esc no problem.

3. when I duplicate an interval (with the duplicate button or with ctrl+c) focus should be placed on that interval.

4. when focus is on an interval alt+up/down should move it one interval down/up

5. On the board view, I want more options for how to handle a manually completed interval. I was thinking...
	- stop alarm without continuing to the next interval
	- add time to interval
I was thinking they would replace the choose interval, reset and next interval buttons while the interval is in limbo waiting for me to do something. This is mostly a forward thinking idea since  future additions will add more buttons here.

6. There's an issue where if an interval is selected, and I hit ctrl+c it duplicates the focused interval, not the selected interval. I was thinking a way to handle this would be to have a rule where if no intervals are selected, ctrl+c copies the focused interval, but if any intervals are selected, the focused interval is ignored and the selected interval(s) are duplicated instead.

7. I want to add a new button to the board UI (to the left of the "choose interval" button) for adding/removing time from the current interval. (note: this wouldn't change what's saved in the interval editor, it'd be ephemoral, think, there's 10min left in the interval but I got distracted for 5 minutes so I need 15min so I add 5 more minutes.
	- you can choose the icon, a clock or a +/- icon would work if there is one
	- I was thinking the menu it brings up would look and behave the same as the duration setter, but with an additional text box to the far left where you'd put + or - (+ by default) and you can toggle it with either up or down arrow keys.

8. When I right click to enter the timer editor on a running timer, it appears that saving it (e.g. hitting done) resets the timer. the timer should continue to run in whatever state it was in, simply updating anything that was updated (I think intervals have IDs, so it should just remain on the same ID with the same amount of time remaining, if the current interval's duration is changed, I was thinking that would be handled by adding/subtracting the time change, for instance if I'm 5min in to a 10min interval, and I change the interval time to 15min, I'd now have 10min remaining when I hit done. Not sure how to handle if I deleted the interval, we should discuss this one before implementing to hammer it out.

9. Would be convenient if notifications disappeared if I started the next interval in app, but idk if kde allows something like that.

10. There's an edge case with the continue button in the notification. If I start the next interval in the app, then hit continue in the notification, it skips to the next interval as if I hit the next interval button, would solve itself if 9 is possible (would make it impossible to hit continue after the next interval is started in app) but if 9 isn't possible I'd like to fix it (make continue do nothing if the next interval is already started)
