#define CHARS_PER_LINE 5
#define FONT_SIZE "5pt"
#define FONT_COLOR "#09f"
#define FONT_STYLE "Arial Black"
#define SCROLL_SPEED 2

// Status display
// (formerly Countdown timer display)

// Use to show shuttle ETA/ETD times
// Alert status
// And arbitrary messages set by comms computer

/obj/machinery/status_display
	icon = 'icons/obj/status_display.dmi'
	icon_state = "frame"
	name = "status display"
	anchored = 1
	density = 0
	use_power = 1
	idle_power_usage = 10
	var/mode = 1	// 0 = Blank
					// 1 = Shuttle timer
					// 2 = Arbitrary message(s)
					// 3 = alert picture
					// 4 = Supply shuttle timer

	var/picture_state	// icon_state of alert picture
	var/message1 = ""	// message line 1
	var/message2 = ""	// message line 2
	var/index1			// display index for scrolling messages or 0 if non-scrolling
	var/index2

	var/frequency = 1435		// radio frequency
	var/supply_display = 0		// true if a supply shuttle display

	var/friendc = 0      // track if Friend Computer mode

	maptext_height = 26
	maptext_width = 32

	// new display
	// register for radio system

/obj/machinery/status_display/New()
	..()
	spawn(5)	// must wait for map loading to finish
		if(radio_controller)
			radio_controller.add_object(src, frequency)

/obj/machinery/status_display/Destroy()
	if(radio_controller)
		radio_controller.remove_object(src,frequency)
	return ..()

// timed process

/obj/machinery/status_display/process()
	if(stat & NOPOWER)
		remove_display()
		return
	update()

/obj/machinery/status_display/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return
	set_picture("ai_bsod")
	..(severity)

// set what is displayed

/obj/machinery/status_display/proc/update()
	if(friendc && mode!=4) //Makes all status displays except supply shuttle timer display the eye -- Urist
		set_picture("ai_friend")
		return

	switch(mode)
		if(0)				//blank
			remove_display()
		if(1)				//emergency shuttle timer
			if(SSshuttle.emergency.timer)
				var/line1
				var/line2 = get_shuttle_timer()
				switch(SSshuttle.emergency.mode)
					if(SHUTTLE_RECALL)
						line1 = "-RCL-"
					if(SHUTTLE_CALL)
						line1 = "-ETA-"
					if(SHUTTLE_DOCKED)
						line1 = "-ETD-"
					if(SHUTTLE_ESCAPE)
						line1 = "-ESC-"
					if(SHUTTLE_STRANDED)
						line1 = "-ERR-"
						line2 = "??:??"
				if(length(line2) > CHARS_PER_LINE)
					line2 = "Error!"
				update_display(line1, line2)
			else
				remove_display()
		if(2)				//custom messages
			var/line1
			var/line2

			if(!index1)
				line1 = message1
			else
				line1 = copytext(message1+"|"+message1, index1, index1+CHARS_PER_LINE)
				var/message1_len = length(message1)
				index1 += SCROLL_SPEED
				if(index1 > message1_len)
					index1 -= message1_len

			if(!index2)
				line2 = message2
			else
				line2 = copytext(message2+"|"+message2, index2, index2+CHARS_PER_LINE)
				var/message2_len = length(message2)
				index2 += SCROLL_SPEED
				if(index2 > message2_len)
					index2 -= message2_len
			update_display(line1, line2)
		if(4)				// supply shuttle timer
			var/line1
			var/line2
			if(SSshuttle.supply.mode == SHUTTLE_IDLE)
				if(SSshuttle.supply.z == ZLEVEL_STATION)
					line1 = "CARGO"
					line2 = "Docked"
			else
				line1 = "CARGO"
				line2 = get_supply_shuttle_timer()
				if(length(line2) > CHARS_PER_LINE)
					line2 = "Error"

			update_display(line1, line2)

/obj/machinery/status_display/examine(mob/user)
	. = ..()
	switch(mode)
		if(1,2,4)
			user << "The display says:<br>\t<xmp>[message1]</xmp><br>\t<xmp>[message2]</xmp>"


/obj/machinery/status_display/proc/set_message(m1, m2)
	if(m1)
		index1 = (length(m1) > CHARS_PER_LINE)
		message1 = m1
	else
		message1 = ""
		index1 = 0

	if(m2)
		index2 = (length(m2) > CHARS_PER_LINE)
		message2 = m2
	else
		message2 = ""
		index2 = 0

/obj/machinery/status_display/proc/set_picture(state)
	picture_state = state
	remove_display()
	overlays += image('icons/obj/status_display.dmi', icon_state=picture_state)

/obj/machinery/status_display/proc/update_display(line1, line2)
	var/new_text = {"<div style="font-size:[FONT_SIZE];color:[FONT_COLOR];font:'[FONT_STYLE]';text-align:center;" valign="top">[line1]<br>[line2]</div>"}
	if(maptext != new_text)
		maptext = new_text

/obj/machinery/status_display/proc/get_shuttle_timer()
	var/timeleft = SSshuttle.emergency.timeLeft()
	if(timeleft > 0)
		return "[add_zero(num2text((timeleft / 60) % 60),2)]:[add_zero(num2text(timeleft % 60), 2)]"
	return "00:00"

/obj/machinery/status_display/proc/get_supply_shuttle_timer()
	var/timeleft = SSshuttle.supply.timeLeft()
	if(timeleft > 0)
		return "[add_zero(num2text((timeleft / 60) % 60),2)]:[add_zero(num2text(timeleft % 60), 2)]"
	return "00:00"

/obj/machinery/status_display/proc/remove_display()
	if(overlays.len)
		overlays.Cut()
	if(maptext)
		maptext = ""


/obj/machinery/status_display/receive_signal(datum/signal/signal)

	switch(signal.data["command"])
		if("blank")
			mode = 0

		if("shuttle")
			mode = 1

		if("message")
			mode = 2
			set_message(signal.data["msg1"], signal.data["msg2"])

		if("alert")
			mode = 3
			set_picture(signal.data["picture_state"])

		if("supply")
			if(supply_display)
				mode = 4



/obj/machinery/ai_status_display
	icon = 'icons/obj/status_display.dmi'
	desc = "A small screen which the AI can use to present itself."
	icon_state = "frame"
	name = "\improper AI display"
	anchored = 1
	density = 0

	var/mode = 0	// 0 = Blank
					// 1 = AI emoticon
					// 2 = Blue screen of death

	var/picture_state	// icon_state of ai picture

	var/emotion = "Neutral"


/obj/machinery/ai_status_display/process()
	if(stat & NOPOWER)
		overlays.Cut()
		return

	update()

/obj/machinery/ai_status_display/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return
	set_picture("ai_bsod")
	..(severity)

/obj/machinery/ai_status_display/proc/update()

	if(mode==0) //Blank
		overlays.Cut()
		return

	if(mode==1)	// AI emoticon
		set_picture("ai_[emotion]")

		return

	if(mode==2)	// BSOD
		set_picture("ai_bsod")
		return


/obj/machinery/ai_status_display/proc/set_picture(state)
	picture_state = state
	if(overlays.len)
		overlays.Cut()
	overlays += image('icons/obj/status_display.dmi', icon_state=picture_state)

#undef CHARS_PER_LINE
#undef FOND_SIZE
#undef FONT_COLOR
#undef FONT_STYLE
#undef SCROLL_SPEED