#!/bin/bash
VERSION="1.0.0"
#
# Bashman
# Author:  lramosde 
# Date:    2023-10-02
# Usage:   bashman.sh [player] [rows] [columns] 
# Description: 
#     This is a simple random maze game where there's a man, a monster
#     and an exit.
#     The man will try to collect as many points in the maze as possible 
#     before reaching the exit. 
#     The monster will try to approach and beat the man. If the monster 
#     catches the man, the man "loses" health. When this happens or when 
#     the exit is reached the game restarts in a new random maze.
#     When the man's health reaches 10% his health can be restored by 
#     reaching a position at the maze.
#     If the man is surrounded by walls or needs to escape the monster, 
#     he can use a bomb to destroy the walls surrounding him.             
#     When there's only one bomb left bombs can be collected at a random
#     point in the maze. 
#     The monster senses vibrations in the maze and tries to match his 
#     coordinates to the man's.
#     Every time the monster hits a wall with his movement it increases 
#     his 'rage' level. When this level reaches 100% the monsters is 
#     able to destroy all the the walls surrounding him.
#     A file ~/.bashman_scores with the player's names and the highest 
#     scores is created.
#     By chance 'bashman' means 'wanker' somewhere :D  
# To Do: 
#     -Some messages should be shown at the middle of the maze
#     -More monsters. 
# 

PLAYER="GUEST"        # default player's name
HEALTH=100            # health in %
HEALTH_HEAL='$'       # symbol to restore the man health 
HEALTH_HEAL_X=0
HEALTH_HEAL_Y=0
HEALTH_HEAL_INC=10    # health-step 

SCORE=0               # the number of points collected in the maze
HIGH_SCORES_MAX=5
HIGH_SCORES_FILE='bashman_scores'    # hidden fle at the home directory
PANEL_SEPARATOR=""

CATCH_REST=""
LIMIT_ERROR=255

MAN='@'   # symbol for the man
MAN_X=0
MAN_Y=0

MONSTER='M'   # symbol for the monster
MONSTER_X=0
MONSTER_Y=0
MONSTER_RAGE=0
MONSTER_RAGE_MAX=100  # monster rage in %
MONSTER_RAGE_INC=10   # monster-rage step  

BOMBS=5            # initial number of bombs
BOMB_RECHARGE='%'  # symbol for the bomb recharge 
BOMB_RECHARGE_X=0
BOMB_RECHARGE_Y=0

MAZE=""            # the maze is represeented as a string.
                   # which is mapped to (x,y) coordinates
MAZE_FULL=""
MAZE_FRAME=""
MAZE_MESSAGE=
MAZE_ROWS=30       # default maze size note the maze size can be defined 
MAZE_COLS=60       # at command line
MAZE_DENSITY=4     # maze density. A high number reduces the maze density 
MAZE_SIZE=${#MAZE} 
MAZE_WALL="#"      # symbol for the maze wall 
MAZE_EMPTY=' '
MAZE_POINT="."     # symbol for the maze points (to be collected) 

MAZE_MIN_X=1
MAZE_MAX_X=28
MAZE_MIN_Y=1
MAZE_MAX_Y=58

MAZE_EXIT="X"      # symbol for the maze exit 
MAZE_EXIT_X=0
MAZE_EXIT_Y=0


echo "Welcome to BASHMAN, a pac-man-like game  (version ${VERSION})"
echo
echo "  Maze size             : ${MAZE_COLS} X ${MAZE_ROWS} (columns X rows) "
echo "  You                   : ${MAN}"
echo "  Monster               : ${MONSTER}"
echo "  Maze walls            : ${MAZE_WALL}"
echo "  Exit (to other maze}  : ${MAZE_EXIT}"
echo "  Health heal (to 100%) : ${HEALTH_HEAL}"
echo "  Bomb recharge (+5)    : ${BOMB_RECHARGE}"
echo 
echo "Controls (WASD or vi/vim commands) "
echo "  w or k  : moves up "
echo "  s or j  : moves down "
echo "  a or j  : moves left "
echo "  d or l  : moves right "
echo "  b or m  : detonates a bomb (destroys nearest walls) "
echo 
echo "Notes:" 
echo "  -A new maze is generated when the monster reach you or you reach the exit."
echo "  -When the monster rage reaches 100% the walls around the monster"
echo "   are destroyed."
echo

# it takes the first two arguments as the number of rows and columns
if [ $# -gt 0 ]
then
  for i
  do
    if [ $i == "-h" ] || [  $i == "--help" ] 
    then
      echo "Usage:"
      echo "  bashman.sh [player] [maze_rows] [maze_columns] [-h or --help]"
      exit 0
    fi
  done

  if [ -z "$1" ] 
  then
    read -p "Enter player name (<ENTER> for default: GUEST): " PLAYER CATCH_REST
  else
    PLAYER="$1"
  fi
else
  read -p "Enter player name (<ENTER> for default: GUEST): " PLAYER CATCH_REST
  if [ -z "$PLAYER" ]
  then
    PLAYER="GUEST"
  fi 
fi

PLAYER="${PLAYER^^}" 

if [ $2 -gt 0 ] ; then MAZE_ROWS=$2 ; fi
if [ $3 -gt 0 ] ; then MAZE_COLS=$3 ; fi


#read -p "Player name (<ENTER> for default: GUEST): " PLAYER CATCH_REST
#
#if [ ! -z "$PLAYER" ]
#then
#  PLAYER="${PLAYER^^}" 
#else
#  PLAYER="GUEST" 
#fi



# it creates a high-score file if there isn't any.
touch "$HOME/.$HIGH_SCORES_FILE"


#
# 'game_over' : It exits the game showing the highest scores
# 
function game_over()
{
 flash_maze 
 show_maze "Beaten!"
 sleep 3 
 echo  "${PLAYER} ${SCORE}" >> "${HOME}/.${HIGH_SCORES_FILE}"
 show_high_scores
 exit 0
}

#
# 'show_high_scores' : show
#
function show_high_scores()
{
 local SCORES_FILE
 local SCORES_FILE_TMP
 local NAME 
 local POINTS
 local I 

 SCORES_FILE="${HOME}/.${HIGH_SCORES_FILE}"
 SCORES_FILE_TMP="${SCORES_FILE}_tmp"

 rm -f $SCORES_FILE_TMP
 touch $SCORES_FILE_TMP

 echo "BASHMAN - Highest scores" 
 echo $PANEL_SEPARATOR
 sort  -r -n -k 2  $SCORES_FILE -o $SCORES_FILE  # sorts the file by score

 I=0 
 while read NAME POINTS
 do 
   if [ $I -eq $HIGH_SCORES_MAX ]
   then
     mv $SCORES_FILE_TMP $SCORES_FILE 
     break 
   fi
   echo "$NAME $POINTS" >> $SCORES_FILE_TMP 
   printf "%20s %7s \n" $NAME  $POINTS
   (( I++ ))
 done < $SCORES_FILE

 echo $PANEL_SEPARATOR
 return 0
}


#
# 'generate_maze rows columns': generates a new maze with the number of 'rows' and 'columns' given
#
function generate_maze()
{
 local M=$1
 local N=$2
 local I
 local J
 local CHOICE 

 if [ $M -le 0 ] || [ $N -le 0 ] 
 then
    echo "Error: Invalid maze size"
    return $LIMIT_ERROR 
 fi 

 (( MAZE_MIN_X=1      ))
 (( MAZE_MAX_X=$2 - 2 ))
 (( MAZE_MIN_Y=1      )) 
 (( MAZE_MAX_Y=$1 - 2 ))


 PANEL_SEPARATOR=""
 for ((I=0; I<$N; I++))
 do
    PANEL_SEPARATOR="${PANEL_SEPARATOR}="
 done


 MAZE=""
 MAZE_FRAME=""
 MAZE_FULL=""
 MAZE_ROWS=$1
 MAZE_COLS=$2

 for ((I=0; I<$M; I++))
 do
   if [ $I -eq 0 ] || [ $I -eq $(($M-1)) ] 
   then
     for ((J=0; J<$N; J++))
     do
       MAZE=${MAZE}${MAZE_WALL} 
       MAZE_FRAME=${MAZE_FRAME}${MAZE_WALL} 
       MAZE_FULL=${MAZE_FULL}${MAZE_WALL} 
     done
     continue
   fi

   MAZE=${MAZE}${MAZE_WALL}   
   MAZE_FRAME=${MAZE_FRAME}${MAZE_WALL} 
   MAZE_FULL=${MAZE_FULL}${MAZE_WALL}

   for ((J=1; J<$N-1; J++))
   do
     MAZE_FRAME=${MAZE_FRAME}${MAZE_EMPTY} 
     MAZE_FULL=${MAZE_FULL}${MAZE_WALL}

     (( CHOICE = $RANDOM % $MAZE_DENSITY )) 
     case $CHOICE in
       0)
        MAZE=${MAZE}${MAZE_WALL}
        ;;
       *)
        MAZE=${MAZE}${MAZE_POINT}
        ;;
     esac 
   done 

   MAZE=${MAZE}${MAZE_WALL}
   MAZE_FRAME=${MAZE_FRAME}${MAZE_WALL} 
   MAZE_FULL=${MAZE_FULL}${MAZE_WALL}
 done

 MAZE_SIZE=${#MAZE} 

 return 0
}


#
# 'get_maze x y' returns a code for what is at a given coordinate x,y 
# Note x is counted from the left (0) to the right (maximum x - 1) and
# and y is counted from the top (0) to the bottom (maximum y - 1).
#
# Maze codes: 
#  point         :   0  (to be collect by the 'man')
#  brick         :   1  (a maze wall, not reachable)
#  empty         :   2  (a point that was already collected)
#  exit          :   3  (an exit to a new maze)
#  man           :   4  (the man)
#  monster       :   5  (the monster)
#  bomb recharge :   6  (bomb recharge)
#  error         : 255  (undefined) 
function get_maze_at()
{
 local INDEX=0

 (( INDEX =  $2 * $MAZE_COLS + $1 )) 

 if [ $INDEX -ge $MAZE_SIZE ] ; then return $LIMIT_ERROR ; fi

# echo ${MAZE:${INDEX}:1} 
 case ${MAZE:${INDEX}:1} in
   ${MAZE_POINT})
    return 0 
   ;;
   ${MAZE_WALL})
    return 1 
   ;;
   ${MAZE_EMPTY})
    return 2 
   ;;
   ${MAZE_EXIT}) 
    return 3 
   ;;
   ${MAN})
    return 4
   ;;
   ${MONSTER})
    return 5
   ;;
   ${BOMB_RECHARGE})
    return 6
   ;;
   ${HEALTH_HEAL})
    return 7
   ;;
   *)
    return $LIMIT_ERROR 
   ;;
 esac
 return 0
}


#
# 'set_maze x y c' sets the character 'c' at the position 'x,y' of the maze
#
# Maze codes: 
#  point         :   0  (to be collect by the 'man')
#  brick         :   1  (a maze wall, not reachable)
#  empty         :   2  (a point that was already collected)
#  exit          :   3  (an exit to a new maze)
#  man           :   4  (the man)
#  monster       :   5  (the monster)
#  bomb recharge :   6  (bomb recharge)
#  error         : 255  (undefined) 
function set_maze_at()
{
 local INDEX=0
 local INDEX_AFTER=0
 local X
 local Y

 X=$1
 Y=$2

 if [ $X -lt $MAZE_MIN_X ] ; then return $LIMIT_ERROR; fi 
 if [ $X -gt $MAZE_MAX_X ] ; then return $LIMIT_ERROR; fi 
 if [ $Y -lt $MAZE_MIN_Y ] ; then return $LIMIT_ERROR; fi 
 if [ $Y -gt $MAZE_MAX_Y ] ; then return $LIMIT_ERROR; fi 

 (( INDEX = $Y * $MAZE_COLS + $X ))

 if [ $INDEX -lt 0          ] ; then (( INDEX = 0             )) ; fi 
 if [ $INDEX -ge $MAZE_SIZE ] ; then (( INDEX = $MAZE_SIZE -1 )) ; fi

 (( INDEX_AFTER  = $INDEX + 1 ))
 
 if [ $INDEX_AFTER  -ge $MAZE_SIZE ] ; then (( INDEX_AFTER  = $MAZE_SIZE - 1)) ; fi 

 MAZE="${MAZE:0:${INDEX}}${3}${MAZE:${INDEX_AFTER}:$MAZE_SIZE}"
 return 0
}


#
# 'show_maze' prints the maze at the top of the screen 
# 
function show_maze() 
{
 local I
 local INDEX

 clear

 for((I=0; I<$MAZE_ROWS; I++))
 do  
   (( INDEX = I * $MAZE_COLS ))
   echo "${MAZE:$INDEX:$MAZE_COLS}"
 done

 show_panel $1 

 return 0
}


#
# 'show_panel' prints the panel with score, health etc
#
function show_panel() 
{
 echo   "${PANEL_SEPARATOR}"
 echo   "$1"
 echo   "${PANEL_SEPARATOR}"
 printf "PLAYER: %15s  SCORE: %7d \n"  "$PLAYER" "$SCORE" 
 printf "HEALTH: %15s%% BOMBS: %7d \n" "$HEALTH" "$BOMBS" 
 printf "MONSTER RAGE  %9s%% \n"      "${MONSTER_RAGE}"  
 echo   "${PANEL_SEPARATOR}"

 return 0
}


#
# 'flash_positions' flashes the positions of the 'player', 'monster', and 'exit'
#
function flash_positions()
{
 set_maze_at $MAZE_EXIT_X      $MAZE_EXIT_Y     "$MAZE_EMPTY"
 set_maze_at $MAN_X            $MAN_Y           "$MAZE_EMPTY"
 set_maze_at $MONSTER_X        $MONSTER_Y       "$MAZE_EMPTY"
 set_maze_at $HEALTH_HEAL_X    $HEALTH_HEAL_Y   "$MAZE_EMPTY"
 set_maze_at $BOMB_RECHARGE_X  $BOMB_RECHARGE_Y "$MAZE_EMPTY"
 show_maze $1

 sleep 1

 set_maze_at $MAZE_EXIT_X      $MAZE_EXIT_Y     "$MAZE_EXIT"
 set_maze_at $MAN_X            $MAN_Y           "$MAN"
 set_maze_at $MONSTER_X        $MONSTER_Y       "$MONSTER"
 set_maze_at $HEALTH_HEAL_X    $HEALTH_HEAL_Y   "$HEALTH_HEAL"
 set_maze_at $BOMB_RECHARGE_X  $BOMB_RECHARGE_Y "$BOMB_RECHARGE"
 show_maze $1

 sleep 1

 return 0
}



#
# 'flash_maze' flashes the whole maze  
#
function flash_maze()
{
 local I
 local INDEX

 clear

 for((I=0; I<$MAZE_ROWS; I++))
 do
   (( INDEX = I * $MAZE_COLS ))
   echo "${MAZE_FULL:$INDEX:$MAZE_COLS}"
 done

 show_panel 

 sleep 1

 show_maze 
}



#
# 'bomb x y' destroys the walls surrounding the coordinate x,y,
#  except for the outermost walls of the maze.
#  It should be used when there is no way out.
#  Note the 'monster' can use the 'bomb' as well.
#
#  point         :   0  (to be collect by the 'man')
#  brick         :   1  (a maze wall, not reachable)
#  empty         :   2  (a point that was already collected)
#  exit          :   3  (an exit to a new maze)
#  man           :   4  (the man)
#  monster       :   5  (the monster)
#  bomb recharge :   6  (bomb recharge)
#  error         : 255  (undefined) 
function bomb()
{
 local XMIN
 local XMAX
 local YMIN
 local YMAX
 local I
 local J

 (( XMIN = $1 - 1 )) 
 (( XMAX = $1 + 1 )) 
 (( YMIN = $2 - 1 )) 
 (( YMAX = $2 + 1 )) 

 for ((I=$XMIN; I<=$XMAX; I++))
 do
   for ((J=$YMIN; J<=$YMAX; J++))
   do
     get_maze_at $I $J
     case $?  in
       1)   # the return code for MAZE_WALL 
         set_maze_at $I $J $MAZE_POINT  
         ;;
       *)
         :
         ;;
     esac
   done        
 done
 show_maze "B O M B!!" 
 return 0
}


#
# 'monster_move' random approach based on the current 'man' coordinates 
#
# Maze codes: 
#  point         :   0  (to be collect by the 'man')
#  brick         :   1  (a maze wall, not reachable)
#  empty         :   2  (a point that was already collected)
#  exit          :   3  (an exit to a new maze)
#  man           :   4  (the man)
#  monster       :   5  (the monster)
#  bomb recharge :   6  (bomb recharge)
#  error         : 255  (undefined) 
function monster_move()
{
 local NEW_X
 local NEW_Y

 NEW_X=$MONSTER_X
 NEW_Y=$MONSTER_Y

 # 'intelligence' but with some randomicity 

 case $(( $RANDOM % 2 ))  in
   0)
     if   [ $MONSTER_X -lt $MAN_X ] ; then 
       (( NEW_X++ )) 
     elif [ $MONSTER_X -gt $MAN_X ] ; then 
       (( NEW_X-- ))
     fi
     ;;
   1)
     if   [ $MONSTER_Y -lt $MAN_Y ] ; then 
      (( NEW_Y++ )) 
     elif [ $MONSTER_Y -gt $MAN_Y ] ; then
     (( NEW_Y-- ))
     fi
     ;;
   *)
     :
     ;;
 esac

 get_maze_at $NEW_X $NEW_Y

 case $? in
    0 | 2 | 3 )
               set_maze_at $MONSTER_X $MONSTER_Y ${MAZE_POINT} 
               MONSTER_X=$NEW_X 
               MONSTER_Y=$NEW_Y 
               set_maze_at $MONSTER_X $MONSTER_Y ${MONSTER}
               ;;
             1)
               (( MONSTER_RAGE += MONSTER_RAGE_INC  ))
               if [ $MONSTER_RAGE -ge $MONSTER_RAGE_MAX ]
               then
                 bomb $MONSTER_X $MONSTER_Y
                 MONSTER_RAGE=0
               fi
               return 1
               ;;
             4)
               (( HEALTH -= HEALTH_HEAL_INC ))
               if [ $HEALTH -eq 0 ] 
               then
                 game_over
               fi 

               if [ $HEALTH -eq $HEALTH_HEAL_INC ]
               then
                 (( HEALTH_HEAL_X = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
                 (( HEALTH_HEAL_Y = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
               fi

               show_maze "Beaten! New maze..."
               sleep 4
               flash_maze
               new_maze

               return 0
               ;;
             6)
               set_maze_at $MONSTER_X $MONSTER_Y ${BOMB_RECHARGE} 
               MONSTER_X=$NEW_X 
               MONSTER_Y=$NEW_Y 
               set_maze_at $MONSTER_X $MONSTER_Y ${MONSTER}
               ;;
             7)
               set_maze_at $MONSTER_X $MONSTER_Y ${HEALTH_HEAL} 
               MONSTER_X=$NEW_X 
               MONSTER_Y=$NEW_Y 
               set_maze_at $MONSTER_X $MONSTER_Y ${MONSTER}
               ;;
             *)
               :
               ;;
 esac    

 return 0 
}



#
# 'bashman_move' : moves the 'man' in the maze based on user input  
#
# Maze codes: 
#  point         :   0  (to be collect by the 'man')
#  brick         :   1  (a maze wall, not reachable)
#  empty         :   2  (a point that was already collected)
#  exit          :   3  (an exit to a new maze)
#  man           :   4  (the man)
#  monster       :   5  (the monster)
#  bomb recharge :   6  (bomb recharge)
#  error         : 255  (undefined) 
function bashman_move() 
{
 local NEW_X
 local NEW_Y

 NEW_X=$MAN_X
 NEW_Y=$MAN_Y

 if [ -z ${1} ]
 then 
   return 0
 fi

 case ${1:0:1} in
   a|h)
       (( NEW_X-- )) 
       show_maze "left"
       ;;
   d|l)
       (( NEW_X++ )) 
       show_maze "right"
       ;;
   s|j)
       (( NEW_Y++ )) 
       show_maze "down"
       ;;
   w|k)
       (( NEW_Y-- )) 
       show_maze "up"
       ;;
   b|m)
       if [ $BOMBS -ge 1 ]
       then
         bomb $MAN_X $MAN_Y 
         (( BOMBS-- ))
         if [ $BOMBS -eq 1 ]
         then  
           (( BOMB_RECHARGE_X = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
           (( BOMB_RECHARGE_Y = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
           set_maze_at $BOMB_RECHARGE_X $BOMB_RECHARGE_Y $BOMB_RECHARGE 
           show_maze  
         fi  
       fi
       return 0
       ;;
     *)
       return 1
       ;;
 esac  

 get_maze_at $NEW_X $NEW_Y

 case $? in
   0)
     (( SCORE++ ))
     set_maze_at $MAN_X $MAN_Y "$MAZE_EMPTY"
     MAN_X=$NEW_X
     MAN_Y=$NEW_Y
     set_maze_at $MAN_X $MAN_Y ${MAN} 
     return 0 
     ;;
   1)
     return $LIMIT_ERROR
     ;;
   2)
     set_maze_at $MAN_X $MAN_Y "$MAZE_EMPTY"
     MAN_X=$NEW_X
     MAN_Y=$NEW_Y
     set_maze_at $MAN_X $MAN_Y ${MAN} 
     return 0 
     ;;
   3)
     set_maze_at $MAN_X $MAN_Y "$MAZE_EMPTY" 
     MAN_X=$NEW_X
     MAN_Y=$NEW_Y
     set_maze_at $MAN_X $MAN_Y ${MAN} 
     show_maze "Exit! New maze..."
     sleep 3
     flash_maze
     new_maze
     return 0 
     ;;
   5)
     (( HEALTH -= HEALTH_HEAL_INC  ))
     if [ $HEALTH -eq 0 ]
     then
       game_over
     fi

     flash_maze

     if [ $HEALTH -eq $HEALTH_HEAL_INC ]
     then
       (( HEALTH_HEAL_X = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
       (( HEALTH_HEAL_Y = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
     fi
     show_maze "Beaten! New maze..." 
     sleep 4
     new_maze
     return 0
     ;;
   6)
     set_maze_at $MAN_X $MAN_Y "$MAZE_EMPTY" 
     MAN_X=$NEW_X
     MAN_Y=$NEW_Y
     set_maze_at $MAN_X $MAN_Y ${MAN} 
     (( BOMBS += 5 ))
     BOMB_RECHARGE_X=0
     BOMB_RECHARGE_Y=0
     show_maze "Bombs recharged..." 
     ;;
   7)
     set_maze_at $MAN_X $MAN_Y "$MAZE_EMPTY" 
     MAN_X=$NEW_X
     MAN_Y=$NEW_Y
     set_maze_at $MAN_X $MAN_Y ${MAN} 
     (( HEALTH = 100 ))
     HEALTH_HEAL_X=0
     HEALTH_HEAL_Y=0
     show_maze "Bombs recharged..." 
     ;;
   *)
     :
     ;;
 esac
 return 0
}


#
# 'new_maze' will generate a new maze 
# with new positions for the man, monster and exit.  
#
function new_maze()
{
 generate_maze $MAZE_ROWS $MAZE_COLS  

 MAN_X=0
 MAN_Y=0
 MONSTER_X=0
 MONSTER_Y=0
 MONSTER_RAGE=0

 while [[ $MAN_X -eq $MONSTER_X ]] && [[ $MAN_Y -eq $MONSTER_Y ]] 
 do
   (( MAN_X     = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
   (( MAN_Y     = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
   (( MONSTER_X = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
   (( MONSTER_Y = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
 done

 set_maze_at $MAN_X           $MAN_Y           $MAN
 set_maze_at $MONSTER_X       $MONSTER_Y       $MONSTER
 set_maze_at $BOMB_RECHARGE_X $BOMB_RECHARGE_Y $BOMB_RECHARGE 
 set_maze_at $HEALTH_HEAL_X   $HEALTH_HEAL_Y   $HEALTH_HEAL 


 MAZE_EXIT_X=$MAN_X
 MAZE_EXIT_Y=$MAN_Y

 while [ $MAZE_EXIT_X -eq $MAN_X ] && [ $MAZE_EXIT_Y -eq $MAN_Y ] 
 do
   (( MAZE_EXIT_X = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
   (( MAZE_EXIT_Y = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
   while [ $MAZE_EXIT_X -eq $MONSTER_X ] && [ $MAZE_EXIT_Y -eq $MONSTER_Y ]
     do
       (( MAZE_EXIT_X = 1 + $RANDOM % ( $MAZE_COLS - 2 ) ))
       (( MAZE_EXIT_Y = 1 + $RANDOM % ( $MAZE_ROWS - 2 ) ))
     done
 done 

 set_maze_at $MAZE_EXIT_X $MAZE_EXIT_Y $MAZE_EXIT 
}


# Here we go ...

new_maze
show_maze

while true  
do
  flash_positions
  DIRECTION=""
  while read  -t 1 -n 1  DIRECTION <&1
  do
    bashman_move $DIRECTION  
    monster_move 
  done
  monster_move 
done


exit 0
