#!/bin/bash

function finicky_details {
final_score=500
dealer_count=0
player_count=4
drop=true
gather=true
}

function options {
while [ -n "$1" ]; do
case $1 in
 --score|-s)
  final_score=${2}
  echo "Final score is set to $final_score"
  shift 2
  ;;
 --no-drop|--nd|-d)
  drop=false
  gather=false
  current_dealer=$(sqlite3 playerbase.db "SELECT MAX(dealer) FROM players")
  dealer_count=$(sqlite3 playerbase.db "SELECT rowID FROM players WHERE dealer IS '$current_dealer'")
  ((dealer_count=dealer_count-1))
  if [[ $dealer_count -gt 4 ]]; then dealer_count=1; fi
   if [[ $dealer_count -lt 1 ]]; then dealer_count=$player_count; fi
  shift
  ;;
  *)
   echo "Invalid option $1. Proceeding without."
   shift
  ;;
esac
done
}

function set_tables {
if $drop; then
sqlite3 playerbase.db "DROP TABLE players" && sqlite3 playerbase.db "DROP TABLE teams"
sqlite3 playerbase.db "CREATE TABLE IF NOT EXISTS players
(name TEXT,
bid INT,
blind INT,
tricks_taken INT,
team TEXT,
dealer INT default 0)"

sqlite3 playerbase.db "CREATE TABLE IF NOT EXISTS teams
(name TEXT,
total_bid INT,
tricks_taken INT,
bags INT DEFAULT 0,
score INT DEFAULT 0)"

else
echo "Picking back up."

fi
}

function gather_players {
 if $gather; then

 num=1
 while [[ $num -le $player_count ]]; do

  echo -n "Who is player $num? "
  read player
  sqlite3 playerbase.db "INSERT INTO players(name) VALUES('$player')"
  ((num=num+1))

 done

 echo -n "Please name team 1: "
 read team_name
 sqlite3 playerbase.db "INSERT INTO teams(name) VALUES('$team_name')"
 sqlite3 playerbase.db "UPDATE players SET team = '$team_name' WHERE rowID IS 1"
 sqlite3 playerbase.db "UPDATE players SET team = '$team_name' WHERE rowID IS 3"
 echo -n "Please name team 2: "

 read team_name
 sqlite3 playerbase.db "INSERT INTO teams(name) VALUES('$team_name')"
 sqlite3 playerbase.db "UPDATE players SET team = '$team_name' WHERE rowID IS 2"
 sqlite3 playerbase.db "UPDATE players SET team = '$team_name' WHERE rowID IS 4"
 fi

 uselessvar="$(echo `sqlite3 playerbase.db "SELECT DISTINCT name FROM players"`)"
 player_array=$uselessvar #to be used later

 uselessvar="$(echo `sqlite3 playerbase.db "SELECT DISTINCT team FROM players"`)"
 team_array=$uselessvar #to be used later
}

function set_dealer() {
 if [[ $dealer_count -gt 0 ]]; then

  ((dealer_count=dealer_count+1))
  if [[ $dealer_count -gt 4 ]]; then dealer_count=1; fi

  dealer=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$dealer_count'")
  sqlite3 playerbase.db "UPDATE players SET dealer = 1 WHERE name IS '$dealer'"
  sqlite3 playerbase.db "UPDATE players SET dealer = 0 WHERE name IS NOT '$dealer'"
  echo -e "\n$dealer is dealing the next round\n"

  else
  dealer=$(sqlite3 playerbase.db "SELECT name FROM players ORDER BY RANDOM() limit 1")
  dealer_count=$(sqlite3 playerbase.db "SELECT rowID FROM players WHERE name IS '$dealer'")
  echo -e "\n$dealer is dealing the first round\n"

 fi
}

function accept_bid {
 num=1
 ((bidder=dealer_count+1))

 while [[ $num -le $player_count ]]; do

  if [[ $bidder -gt 4 ]]; then bidder=1; fi

  player=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$bidder'")
  echo -n "What is $player's bid? "
  read bid 

  case $bid in
   [1-9]|1[0-3])
     sqlite3 playerbase.db "UPDATE players SET bid = '$bid' WHERE rowID IS '$bidder'"
     ((num=num+1)) && ((bidder=bidder+1))
    ;;
    0)
   echo -n "Is $player blind? "
   read answer

    case $answer in
   	 yes|y|ye|yse|esy|eys|0)
     sqlite3 playerbase.db "UPDATE players SET bid = '$bid' WHERE rowID IS '$bidder'"
     sqlite3 playerbase.db "UPDATE players SET blind = 1 WHERE rowID IS '$bidder'"
     echo "Let's hope they're psychic."
    ;;
    *)
     sqlite3 playerbase.db "UPDATE players SET bid = '$bid' WHERE rowID IS '$bidder'"
     sqlite3 playerbase.db "UPDATE players SET blind = 0 WHERE rowID IS '$bidder'"
     echo "Player has vision."
    ;;
    esac

    ((num=num+1)) && ((bidder=bidder+1))
  ;;
  back|oops|no)
   if [[ num -gt 1 ]]; then ((num=num-1)) && ((bidder=bidder-1)); else echo -n "We're just getting started. "; fi
   if [[ $bidder -lt 1 ]]; then bidder=$player_count; fi
  ;;
  *)
   echo -n "Let's try that again. "
  esac

 done

 num=1
 ((bidder=dealer_count+1))
 echo
 while [[ $num -le $player_count ]]; do

  if [[ $bidder -gt 4 ]]; then bidder=1; fi

  player=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$bidder'")
  bid=$(sqlite3 playerbase.db "SELECT bid FROM players WHERE rowID IS '$bidder'")
  echo "$player bid $bid."
  ((num=num+1))
  ((bidder=bidder+1))

 done

echo
for team in ${team_array}; do
 total_bid=$(sqlite3 playerbase.db "SELECT SUM(bid) FROM players WHERE team IS '$team'")
 sqlite3 playerbase.db "UPDATE teams SET total_bid = '$total_bid' WHERE name IS '$team'"
 echo "$team bid $total_bid"
done
 echo
}

function count_tricks {
 num=1
 ((bidder=dealer_count+1))

 while [[ $num -le $player_count ]]; do

  if [[ $bidder -gt $player_count ]]; then bidder=1; fi

  player=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$bidder'")
  echo -n "How many tricks did $player take? "
  read tricks_taken

  case $tricks_taken in
   [0-9]|1[0-3])
     sqlite3 playerbase.db "UPDATE players SET tricks_taken = '$tricks_taken' WHERE rowID IS '$bidder'"
     ((num=num+1)) && ((bidder=bidder+1))
    ;;
   back|oops|no)
    #if [[ bidder -eq 1 ]]; then bidder=$player_count; else ((bidder=bidder-1))
    if [[ num -gt 1 ]]; then ((num=num-1)) && ((bidder=bidder-1)); else echo -n "We're just getting started. "; fi
    if [[ $bidder -lt 1 ]]; then bidder=$player_count; fi
   ;;
   *)
    echo -n "Let's try that again. "
  esac

done

 echo
 for team in ${team_array}; do
  total_tricks=$(sqlite3 playerbase.db "SELECT SUM(tricks_taken) FROM players WHERE team IS '$team'")
  sqlite3 playerbase.db "UPDATE teams SET tricks_taken = '$total_tricks' WHERE name IS '$team'"
  echo "Team $team took $total_tricks."
 done
}

function calculate_scores {
for player in $player_array; do

  bid=$(sqlite3 playerbase.db "SELECT bid FROM players WHERE name IS '$player'")
  team=$(sqlite3 playerbase.db "SELECT team FROM players WHERE name IS '$player'")
  blind=$(sqlite3 playerbase.db "SELECT blind FROM players WHERE name IS '$player'")

  case $blind in
   0)
  if [[ $bid -eq 0 &&  $tricks_taken -eq 0 ]]; then
   sqlite3 playerbase.db "UPDATE teams SET score=score+50 WHERE name IS '$team'"
  elif [[ $bid -eq 0 &&  $tricks_taken -gt 0 ]]; then
   sqlite3 playerbase.db "UPDATE teams SET score=score-50 WHERE name IS '$team'"
  fi
   ;;
   1)
  if [[ $bid -eq 0 &&  $tricks_taken -eq 0 ]]; then
   sqlite3 playerbase.db "UPDATE teams SET score=score+100 WHERE name IS '$team'"
  elif [[ $bid -eq 0 &&  $tricks_taken -gt 0 ]]; then
   sqlite3 playerbase.db "UPDATE teams SET score=score-100 WHERE name IS '$team'"
  fi
  ;;
  esac

  ((num=num+1))
  ((bidder=bidder+1))
 done

echo
 for team in $team_array; do

  total_bid=$(sqlite3 playerbase.db "SELECT total_bid FROM teams WHERE name IS '$team'")
  total_tricks=$(sqlite3 playerbase.db "SELECT tricks_taken FROM teams WHERE name IS '$team'")

 if [[ $total_tricks -ge $total_bid ]]; then # update scores for tricks taken based on bid
  sqlite3 playerbase.db "UPDATE teams SET score=score+'$total_bid'*10+('$total_tricks'-'$total_bid') WHERE name IS '$team'"
 else
  sqlite3 playerbase.db "UPDATE teams SET score=score-('$total_bid'*10) WHERE name IS '$team'"
 fi

 if [[ $total_tricks -gt $total_bid ]]; then # update bags total
  sqlite3 playerbase.db "UPDATE teams SET bags=bags+'$total_tricks'-'$total_bid' WHERE name IS '$team'"
  total_bags=$(sqlite3 playerbase.db "SELECT bags FROM teams WHERE name IS '$team'")
#echo $(sqlite3 playerbase.db "SELECT bags FROM teams WHERE name IS '$team'")
 fi

 if [[ $total_bags -ge 10 ]]; then
  sqlite3 playerbase.db "UPDATE teams SET score=score-100 WHERE name IS '$team'"
echo "reset bags"
  sqlite3 playerbase.db "UPDATE teams SET bags=0 WHERE name IS '$team'"
echo $(sqlite3 playerbase.db "UPDATE teams SET bags=0 WHERE name IS '$team'")

 fi

 team_score=$(sqlite3 playerbase.db "SELECT score FROM teams WHERE name IS '$team'")
 echo "$team is at $team_score"

 done

 team_one_score=$(sqlite3 playerbase.db "SELECT score FROM teams WHERE rowID IS '1'")
 team_two_score=$(sqlite3 playerbase.db "SELECT score FROM teams WHERE rowID IS '2'")
 echo
}

function ending_ceremony {
winning_score=$(sqlite3 playerbase.db "SELECT MAX(score) FROM teams")
winning_team=$(sqlite3 playerbase.db "SELECT name FROM teams WHERE score IS '$winning_score'")
echo "Congratulations, ${winning_team} with ${winning_score}!"
}



finicky_details
options $@
set_tables
gather_players

while [[ ($team_one_score -lt $final_score && $team_two_score -lt $final_score) || $team_one_score -eq $team_two_score ]]; do
set_dealer
accept_bid
count_tricks
calculate_scores
done

ending_ceremony


#have variable number of teams by moduloing the number of players by 2. if results >0, then no teams. otherwise, split up by twos.
