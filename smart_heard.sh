#!/bin/bash

###############################################################
# Smart List for fsq
# Budd Churchward WB7FHC
# email: wb7fhc@arrl.net
V_DATE=09/02/19
#
# Run this script in a terminal window while Flidigi FSQ is also
# running. Make sure that you have enabled the Heard Log in FSQ
#     Configure > Rig Control
#       Modems > FSQ
#         Heard log fsq_heard_log.txt [Enable]
#
# If you have a copy of fsq_names.csv,
# put it in /home/pi/.fildigi/temp
#
# Your Smart Heard List is stored as a file so you can shut down
# your station and bring it up later with the data maintained.
# All times will be recalculated and then updated as stations are
# heard again.
#
# If you are using a Signalink you need to configure Rig > GPIO
# even though you don't really use it. Check the box for GPIO 4 (BCM 23)
# and check the matching value=1 ... at this time I am not sure how
# this works if you are not using an Rpi ... let us know what you find out
#
# This version uses a GPIO pin to tell when the station has transmitted,
# allowing the user's own call sign to appear in the smart heard list
# It may only work on the Rpi. If you are not using an Rpi or GPIO PTT
# the script will still function but your own call might not appear in
# the list.
#
#
# KEYBOARD COMMANDS:
#   [Escape] ... stop running script
#   [End]    ... also stops the script
#   [Insert] ... add new call and name to fsq_names.csv
#   [Delete] ... remove a call from your heard list
#   [PgDwn]  ... show more stations heard
#   [PgUp]   ... show fewer stations heard
#   [RT Arrow] ... show dates and time on the display
#   [LT Arrow] ... hide dates and time on the display
#   [UP Arrow] ... increase the update interval in steps of 5 seconds
#   [DN Arrow] ... decrease the update interval to minimum of 5 seconds
#
# SMART LIST FILES:
#   smart_heard.sh
#     this file
#     located @ /home/pi/smart_heard.sh
#     use: 'chmod 755 smart_heard.sh' to make executable
#     use: './smart_heard.sh' to launch in term. window
#
#   fsq_heard_log.txt
#     list of all stations heard with UTC and SNR
#     created by Fldigi
#     located @ /home/pi/.fldigi/temp/fsq_heard_log.txt
#
#   smart_heard.list
#     working file for this script
#     contains:
#         call,epoch time,op name
#     located @ ~/.flidigi/temp/smart_heard.list
#
#   temp.dat
#     temporary file built from smart_heard.list
#     will become smart_heard.list
#     located @ ~/.fildigi/temp/temp.dat
#     this file is short lived and is normally
#     not seen in directory ... script will delete
#     file if it exists at wrong time
#
#   fsq_names.csv
#     lookup table to match callsign and op's name
#     located @ ~/.fldigi/temp/fsq_names.csv
#
# TEXT COLORS:
#    YELLOW ... station heard less than 10 minutes ago
#    GREEN  ... station heard less than 1 hour ago
#    WHITE  ... station heard within last 24 hours
#    BLUE   ... station not heard in last 24 hours
#
####################################################
#SHOW_RADIO=false   # if true heard list will show L and R s
SHOW_RADIO=$2   # if true heard list will show L and R s
LR_CHANNEL=$1

# GPIO pin on Rpi for UDRC-II used to
# tell that this station has transmitted
# Works with Signalink even though pin
# is not used for PTT
if [[ $LR_CHANNEL == "right" ]]; then
  PTTpin=4
  RADIO=R
else
  PTTpin=26
  RADIO=L
  LR_CHANNEL='left'
fi



FSQ_PATH=~/.fldigi-$LR_CHANNEL/temp
cd $FSQ_PATH
lastGuy='nobody'
includeDT=0        # to toggle between showing dates
                   # and times on the display use RT Arrow
                   # to show D&T use LT Arrow to hide D&T

fullList=1         # to switch between short, medium & long lists
                   # default is medium list
                   # 0 = short list is the last 24 hours
                   # 1 = medium list is the last 20 stations
                   # 2 = full list is all stations up to 99
max=21             # default show only last 20

refreshInterval=60 # default is 10 seconds can be increased
                   # or decreased in steps of 5 with the
                   # Up and Down Arrows ... minimum of 5 sec.





OPS_NAMES=~/WB7FHC/fsq_names.csv   # look up table

if [[ ! -f $OPS_NAMES ]]; then
  # init the table
  echo 'nocall,noname' >> $OPS_NAMES
fi

# LET'S MAKE SURE WE HAVE OUR fsq_heard_log
# THIS FILE WILL BE .txt unless we my net control
# SOFTWARE IS RUNNING. IF IT IS, IT WILL BE .text 
heardSwap=fsq_heard_log.txt

if [[ -f $heardSwap ]]; then
  clear
  mv $heardSwap fsq_heard_log.text
fi

  heardFile=fsq_heard_log.text
  if [[ -f $heardFile ]]; then
    clear
  else
    tput sgr0     # restore term. settings
    tput cnorm    # normal cursor
    echo
    echo Use Fldigi FSQ Config to enbable the heard log.
    echo Then restart Fldigi
    exit
  fi
 heardFile=fsq_heard_log.*

# WE ARE GOING TO GO GRAB THIS STATION'S CALLSIGN
# FROM THE FLDIGI CONFIG FILE
CONFIG_FILE=~/.fldigi-$LR_CHANNEL/fldigi_def.xml
while read line; do
  if [[ $line == '<'MYCALL'>'* ]];then
    myCall=$line
    myCall=${myCall#*>} # everything after the first >
    myCall=${myCall%<*} # everything before the first <
  fi

done <$CONFIG_FILE
echo -ne '\033]0;'Smart List 'for' fsq_$myCall' ['$LR_CHANNEL' radio]\007'

# RENAME THE TERMINAL WINDOW
function showTemp {
cpu=$(cat /sys/class/thermal/thermal_zone0/temp)
echo -ne '\033]0;CP: '$((cpu/1000)) 'c ['$LR_CHANNEL' radio]\007'
}



# SET UP SOME BACKGROUND AND FOREGROUND COLORS
# TO EXPERIMENT WITH ... SOME OF THESE WE DON'T USE
    BG_BLUE="$(tput setab 4)"
    BG_GREEN="$(tput setab 2)"
    BG_BLACK="$(tput setab 0)"
    BG_WHITE="$(tput setab 7)"
    BG_CYAN="$(tput setab 6)"
    BG_YELLOW="$(tput setab 3)"
    BG_MAGENTA="$(tput setab 5)"
    FG_GREEN="$(tput setaf 2)"
    FG_RED="$(tput setaf 1)"
    FG_WHITE="$(tput setaf 7)"
    FG_MAGENTA="$(tput setaf 5)"
    FG_YELLOW="$(tput setaf 3)"
    FG_CYAN="$(tput setaf 6)"
    FG_BLUE="$(tput setaf 4)"

#####################################################################
# Although 'Clear' appears to clear the screen, it does not
# clear the terminal window buffer and the scroll bar rolls
# back the old data. This function clears the buffer and prevents that
#
function setScreen {
    printf "\033c"  # clear terminal window buffer
    echo -n ${BG_BLUE}
    tput civis # turn off the cursor
    tput bold
    tput clear
}

  setScreen # clears screen and window buffer

  # title splash is shown for only 3 seconds
  echo '  Smart Heard List for FSQ by WB7FHC'
  echo '  Version Date '$V_DATE
  tempFile=hold.dat  # allows us to put newest entries on top of list
  refreshCount=$((refreshInterval-3))     # jump start on refresh cycle so header is only on 3 secs.

  # find out the last time the heard log was changed
  # we check it later to see if the file has been updated
  thisStamp=$(stat $heardFile -c %Y)
  lastStamp=$thisStamp # when these two don't match
                       # we know something has happened

  ourFile=~/WB7FHC/smart_heard.list
  if [[ ! -f $ourFile ]]; then
    touch $ourFile    # create the file if it doesn't exist
  fi

  # DOES OUR OLD HEARD LIST EXIST? IF SO CONVERT IT.
  # EARLIER VERSIONS DID NOT INCLUDE DATE OR TIME IN LIST
#  oldFile=smart.list
#  if [[ -f $oldFile ]]; then
#     while IFS=, read thisGuy hisStamp hisName; do
#       echo -n $thisGuy','$hisStamp',' >> $ourFile
#       echo -n `date -d @$hisStamp +"%m-%d,%R,"` >> $ourFile
#       echo $hisName >> $ourFile
#     done <$oldFile
#     mv $oldFile "smart_list.old"  # rename the old file
                                   # so we only do this once
# fi



########################################################
# LOOK UP THE OP'S NAME IN OUR CSV FILE
# (APPOLOGIES TO OTHER GENDERS)
#
function findHisName {
  hisName="....."

 # we keep reading the whole list even after the name is found
  # this means we can correct a name by simply adding it again
  # later in the list ... we will use the last match found
  while IFS=, read -r thisCall thisName; do
    if [[ $thisCall == $lastGuy ]]; then
       hisName=$thisName
       if [[ $SHOW_RADIO == 'show' ]]; then
         hisName=$RADIO' '$thisName
       fi
      # we will show this user's name as "me"
      if [[ $thisCall == $myCall ]]; then
        hisName='me'
        if [[ $SHOW_RADIO == 'show' ]]; then
          hisName=$RADIO' me'
        fi
      fi
    fi
  done <$OPS_NAMES
#  if [[ $SHOW_RADIO == 'show' ]]; then
#    hisName=$RADIO' '$thisName
#  fi


}

function doTheInsert {
         stty echo     # restore echo
         tput el       # clear this line if needed
         # user must type line exactly as it will appear in csv file
         # currently this version does not support a backspace !!!
         echo
         echo -n ${FG_GREEN}" Enter <Callsign>,<Name> "
         read hisName

         if [[ $hisName > ' ' ]]; then
           echo $hisName >>  $OPS_NAMES
         fi
         echo -n ${FG_WHITE}
         echo 'added '$hisName # note this string is actually
                               # a call and a name separted
                               # by a comma!
         refreshList
}


################################################
# WE SCAN THE KEYBOARD LOOKING FOR STROKES WITH
# ESCAPE KEY SEQUENCES THESE ARE THE NAV KEYS
#
function scanKeyboard { 
  navKey=''
   read -s -n1 -t 1  key  # 2 seconds to do it
   # if the keyboard doesn't have an [insert] use the ^
   if [ "$key" == '^' ]; then
     doTheInsert
   fi

   case "$key" in

    $'\e')        # escape key
       yesEscape=1
       read -sN2 -t 0.0002 a2 a3
       navKey+=${a2}${a3} # catch the next two characters in the sequence
       if [[ $a2 == '['* ]]; then
         yesEscape=0
       fi
       #echo $navKey

       # [Insert] key is used to add new calls and names to csv list
       if [ "$navKey" == "[2" ]; then  # insert
         read -sN1 -t  0.0001 a2  # strip off the ~
         doTheInsert
       fi

      if [ "$navKey" == "[3" ]; then #delete
         read -sN1 -t  0.0001 a2  # strip off the ~
         stty echo     # restore echo
         tput el       # clear this line if needed
         echo -e ${FG_GREEN}"\n Enter the number of the line"
         echo -n ${FG_GREEN}" you want to delete: "
         read delNum
         if [[ -f $tempFile ]]; then
           rm $tempFile # delete this file if it happens to exist
         fi
         j=0
         while IFS=, read thisGuy hisStamp hisDate hisTime hisName; do
           j=$((j+1))
          # count them and write them to the temp file
           # skipping the number the user entered
           if [[ $j != $delNum ]]; then
             echo $thisGuy','$hisStamp','$hisDate','$hisTime','$hisName >> $tempFile
           fi
         done <$ourFile
         mv $tempFile $ourFile  # rename the temp file
         refreshList
      fi

      # use up arrow to increase refresh interval
       if [ "$navKey" == "[A" ]; then  #Up Arrow
         read -sN1 -t  0.0001 a2  # strip off the ~
         refreshInterval=$((refreshInterval+5))

         if [[ -f $tempFile ]]; then
           rm $tempFile # delete this file if it exists
         fi
         refreshList
         echo -e "\n refreshInterval: "$refreshInterval" seconds"
       fi

      # use down arrow to decrease refresh interval
       if [ "$navKey" == "[B" ]; then  #Down Arrow
         read -sN1 -t  0.0001 a2  # strip off the ~
         if ((refreshInterval>5)); then
            refreshInterval=$((refreshInterval-5))
         fi

         if [[ -f $tempFile ]]; then
           rm $tempFile # delete this file if it exists
         fi
         refreshList
         echo -e "\n refreshInterval: "$refreshInterval" seconds"
       fi

      # use right arrow to show dates and times
       if [ "$navKey" == "[C" ]; then  # Right Arrow
         read -sN1 -t  0.0001 a2  # strip off the ~
         includeDT=1

         if [[ -f $tempFile ]]; then
           rm $tempFile # delete this file if it exists
         fi
         refreshList
       fi

      # use left arrow to hide dates and times
       if [ "$navKey" == "[D" ]; then  # Left Arrow
         read -sN1 -t  0.0001 a2  # strip off the ~
         includeDT=0
         if [[ -f $tempFile ]]; then
           rm $tempFile # delete this file if it exists
         fi
         refreshList
       fi

       # [PgUp] key is used to switch to shorter list of stations
       if [ "$navKey" == "[5" ]; then  # page up
          read -sN1 -t  0.0001 a2  # strip off the ~
          if (( fullList > 0 )); then
            fullList=$((fullList-1))
          fi

          if [[ -f $tempFile ]]; then
            rm $tempFile # delete this file if it exists
          fi
          refreshList
       fi

       # [PgDown] key is used to switch to longer list of stations
       if [ "$navKey" == "[6" ]; then  # page down
         read -sN1 -t  0.0001 a2  # strip off the ~
         if (( fullList < 2 )); then
           fullList=$((fullList+1))
         fi
         if [[ -f $tempFile ]]; then
           rm $tempFile # delete this file if it exists
         fi
         refreshList
       fi
   esac

   # if only the [Esc] key was pressed we shut down the script
   if (( yesEscape == 1 )); then
     tput sgr0     # restore term. settings
     tput clear    # clear window
     tput cnorm    # normal cursor
     echo bye-bye
     exit    # bye-bye we're outa here
   fi 

}

##############################################################
# WE WILL USE THE GPIO PIN TO TELL WHEN THIS STATION TRANSMITS
# IT WILL BE HIGH (1) WHEN XMITR IS ON ... WE THEN WAIT FOR IT
# TO GO LOW (0) AGAIN WHEN IT IS OFF
#
function checkPTT {
  xmit=$(gpio read $PTTpin)
  if [ $xmit == "1" ]; then
    ptt=1
  else
    # ptt is now off but we only want to do this once
    if (( ptt == 1 )); then
      thisStamp=`date +"%s"` # epoch time (seconds since Jan. 1, 1970)
      ptt=0  # so we don't do this again
      lastGuy=$myCall
      spotNewGuy
      echo $lastGuy','$thisStamp','$hisName >> $tempFile  


      thisStamp=$lastStamp
      refreshCount=$((refreshInterval-5)) # show this line for only 5 seconds
      lastGuy="nobody"
    fi
  fi

}

#check to see if the log file has been stopped and restarted
function checkHeardSwap {
  if [[ -f $heardSwap ]]; then
    clear
    echo -n ${FG_GREEN}
    echo '     Log file has been restarted'
    sleep 3
    mv $heardSwap fsq_heard_log.text
  fi
}


#############################################
# WE REPEATEDLY CHECK FLDIGI'S HEARD LOG TO
# SEE IF ANYTHING NEW HAS BEEN WRITTEN TO IT
# WE ALSO SCAN THE KEYBOARD AND CHECK THE 
# GPIO PTT PIN ONCE EACH SECOND.
# IF NONE OF THESE THINGS HAPPEN WE REFRESH THE
# AT THE END OF THE INTERVAL TO UPDATE THE TIMES.
#
function waitForOne {
  # Loop here until the file's time stamp changes
  while [[ $thisStamp == $lastStamp ]]
    do
      checkHeardSwap
      checkPTT
      thisStamp=$(stat $heardFile -c %Y)
      scanKeyboard
      refreshCount=$((refreshCount+1))
      if ((refreshCount>=refreshInterval)); then
        if [[ -f $tempFile ]]; then
          rm $tempFile # remove this file if it exists
        fi
        refreshList
      fi
      tempCount=$((tempCount+1))
      if ((tempCount==60)); then
	showTemp
	tempCount=0
      fi
    done
    lastStamp=$thisStamp

}

################################################
# WE KNOW THE LOG FILE HAS CHANGED SO WE
# GO COLLECT THE CALLSIGN OF THE LAST ENTRY
# .... to the hackers: this function also
# .... reads the signal rpt (snr) but we
# .... never use it. If you want to, have at it!
#
function findLastLine {
  while IFS=, read -r thisDate thisTime thisCall snr; do
    lastGuy=$thisCall
  done <$heardFile
}


##########################################
# TEXT CLUE TO SHOW SHORT LIST OPTION
#
function shortListPrompt {
  echo -n ${FG_MAGENTA}
  if [[ $fullList == 0 ]]; then
    echo  " [PgDwn] to show last 20"
  fi

  if [[ $fullList == 1 ]]; then
    echo  " [PgDwn] to show all "$lineNum
    echo  " [PgUp] to show last 24hrs"
  fi

  if [[ $fullList == 2 ]]; then
    echo  " [PgUp] to show last 20"
  fi


  if [[ $includeDT == 1 ]]; then
    echo -n " [LF Arrow] to hide dates & times"
  else
    echo -n " [RT Arrow] to show dates & times"
  fi

  # LET USER KNOW HOW TO ADD A MISSING NAME
  if [[ $insert != 'name found' ]]; then
    echo
    echo ' Press [INSERT] to Enter Name for '$insert
  fi
}

#######################################
# CALCULATE THE TIMES AND TEXT COLORS
#
function calculateTimes {
  #calculate current time segments
  duration=$((currentStamp - hisStamp))
  mins=$(($duration / 60))
  secs=$(($duration % 60))
  hours=$(($mins / 60))
  mins=$(($mins % 60))
  days=$(($hours / 24))
  lineNum=$((lineNum+1))
  if [[ $fullList == 0 ]]; then
    if (( days > 0 )); then
      max=$lineNum
    fi
  else
    max=99
    if [[ $fullList == 1 ]]; then
       max=21
    fi

  fi

  # Determine text color based on times
  # Color is already Yellow
  if  ((mins > 9)); then
    echo -n ${FG_GREEN} # less than 1 hour
  fi
  if  ((hours > 0)); then
    echo -n ${FG_WHITE} # less than 24 hours
  fi
  if ((days > 0)); then
    hours=$(($hours % 24))
    echo -n ${FG_BLUE}  # one day or more
  fi

}

###########################################
# NOW WE SHOW THE LISTING ON THE SCREEN
#
function printData {
    echo -n ' '
    if ((lineNum < 10)); then
      echo -n ' '
    fi
    echo -n $lineNum' '

    # USER HAS THE CHOICE OF WHETHER TO SHOW
    # DATES AND TIMES IN THE LISTING.  USE
    # LEFT AND RIGHT ARROWS TO TOGGLE ON AND OFF.
    if ((includeDT == 1)); then
      echo -n $hisDate' '$hisTime
    fi

    echo -n ' '$thisGuy
    echo -n -e "\t" # tab
    if ((days>0)); then
      if ((days<10)); then
        echo -n ' '
      fi
      echo -n $days'd '
    fi

    if ((hours <10)); then
      if ((days >0)); then
        echo -n '0'
      else
        echo -n ' '
      fi
    fi
    echo -n $hours'h '
    if ((mins <10)); then
      echo -n '0'
    fi
    echo -n $mins'm '
    if ((days <1)); then
      if ((secs <10)); then
        echo -n '0'
      fi
      echo -n $secs's '
    fi
    echo  $hisName
}

#############################################################
# FIND OUT WHEN WE HEARD THIS STATION THE LAST TIME
#
function lastTimeHeard {
  while IFS=, read thisGuy hisStamp hisDate hisTime hisName; do
    if [[ $thisGuy == $lastGuy ]]; then
      calculateTimes
    fi
  done <$ourFile
}

###############################################################
# A STATION JUST APPEARED AT THE END OF THE MONITOR LOG
# LET'S GO SHOW WHO IT WAS AT THE TOP OF THE WINDOW
#
function justHeardSomeone {
    clear
    noClear=1
    echo -n '  1  '$lastGuy': '$hisName' after '
    lastTimeHeard
    echo -n ${FG_YELLOW}
    if ((days>0)); then
      echo  -n $days' day'
      if ((days>1)); then
        echo -n 's'
      fi
      echo
    else
      if ((hours>0)); then
        echo -n $hours' h '
        if ((mins>0)); then
         echo $mins' m '
        else
         echo
        fi
      else
        if ((mins<1)); then
          echo 'less than 1 minute'
        else
          echo  -n $mins' minute'
          if ((mins>1)); then
            echo 's'
          else
            echo
          fi
        fi
      fi
    fi
    refreshCount=$((refreshInterval-3)) # show this line for only 3 seconds
    lineNum=1
}


#######################################
# WE UPDATE THE LIST ON THE SCREEN
# AT THE END OF EACH REFRESH INTERVAL,
# SOONER IF A STATION IS HEARD OR A
# KEY IS PRESSED
#
function refreshList {
  refreshCount=0
  insert="name found"
  setScreen
  lineNum=0
  echo -n  ${FG_YELLOW} # for heard less than 10 mins

  currentStamp=`date +" %s"` # epoch time (seconds since Jan. 1, 1970)

  if [[ $lastGuy != 'nobody' ]]; then
    justHeardSomeone
  fi

  while IFS=, read thisGuy hisStamp hisDate hisTime hisName; do
    # We don't reprint the last one found he is already there
    # This test will also eliminate duplicates in list that might
    # occur if user aborts script at an awkward moment
    if [[ $thisGuy != $lastGuy ]]; then
      # stuff to do if we didn't find a name
      if [[ $hisName == '.....' ]]; then
        # check again to see if his name has since been added
        holdOne=$lastGuy  # we need to hang on to this call sign
        lastGuy=$thisGuy
        findHisName
        lastGuy='nobody'
        insert='name found'
        if [[ $hisName == '.....' ]]; then
          # name is still not there
          insert=$thisGuy
        fi
        lastGuy=$holdOne # restore the call sign that we hung on to
      fi

      # write data to temp file
      if [[ $thisGuy>'' ]]; then
        echo $thisGuy','$hisStamp','$hisDate','$hisTime','$hisName >> $tempFile
      fi

      calculateTimes

      if ((lineNum < max )); then
        printData
      fi
    fi
  done <$ourFile


  shortListPrompt

  # rename temp file to the working version
  if [[ -f $tempFile ]]; then
    mv $tempFile $ourFile
  fi
}


###########################
# FIND OUT WHO JUST XMITTED
# AND WRITE HIM AT THE TOP
# OF OUR TEMP FILE
#
function spotNewGuy {
  #clear
  findHisName
  echo -n $lastGuy','$thisStamp',' >> $tempFile
  echo -n `date -d @$thisStamp +"%m-%d,%R,"` >> $tempFile
  echo $hisName >> $tempFile

  refreshList
  lastGuy="nobody"
}


#############################
# OUR MAIN LOOP RUNS FOREVER
#
while true; do
  waitForOne
  findLastLine
  spotNewGuy
done


