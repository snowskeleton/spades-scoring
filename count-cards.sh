#!/bin/bash
dealer_count=0

function gather_players {
num=1
 while [[ $num -lt 5 ]]; do
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
 uselessvar="$(echo `sqlite3 playerbase.db "SELECT DISTINCT team FROM players"`)"
 team_array=$uselessvar #to be used later
}

function set_dealer() {
 if [[ $dealer_count -gt 0 ]]; then
  ((dealer_count=dealer_count+1))
 if [[ $dealer_count -gt 4 ]]; then dealer_count=1; fi
  dealer=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$dealer_count'")
  echo "$dealer is dealing the next round"
  else
  dealer=$(sqlite3 playerbase.db "SELECT name from players order by random() limit 1")
  dealer_count=$(sqlite3 playerbase.db "SELECT rowID FROM players WHERE name IS '$dealer'")
  echo "$dealer is dealing the first round"
 fi
}

function accept_bid {
 num=1
 ((bidder=dealer_count+1))
 while [[ $num -lt 5 ]]; do
  if [[ $bidder -gt 4 ]]; then bidder=1; fi
  echo -n "What is player $bidder's bid? "
  read bid 
  sqlite3 playerbase.db "UPDATE players SET bid = '$bid' WHERE rowID IS '$bidder'"
  ((num=num+1))
  ((bidder=bidder+1))
 done
 num=1
 ((bidder=dealer_count+1))
 while [[ $num -lt 5 ]]; do
  if [[ $bidder -gt 4 ]]; then bidder=1; fi
  player=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$bidder'")
  bid=$(sqlite3 playerbase.db "SELECT bid FROM players WHERE rowID IS '$bidder'")
  echo "$player bid $bid."
  ((num=num+1))
  ((bidder=bidder+1))
 done
}

function calculate_scores {
 num=1
 ((bidder=dealer_count+1))
 while [[ $num -lt 5 ]]; do
  if [[ $bidder -gt 4 ]]; then bidder=1; fi
  player=$(sqlite3 playerbase.db "SELECT name FROM players WHERE rowID IS '$bidder'")
  echo -n "How many tricks did $player take? "
  read tricks_taken
  sqlite3 playerbase.db "UPDATE players SET tricks_taken = '$tricks_taken' WHERE rowID IS '$bidder'"
  ((num=num+1))
  ((bidder=bidder+1))
 done
 for team in $team_array; do
  total_bid=$(sqlite3 playerbase.db "SELECT SUM(bid) FROM players WHERE team IS '$team'")
  sqlite3 playerbase.db "UPDATE teams SET total_bid = '$total_bid' WHERE name IS '$team'"
  total_tricks=$(sqlite3 playerbase.db "SELECT SUM(tricks_taken) FROM players WHERE team IS '$team'")
  sqlite3 playerbase.db "UPDATE teams SET tricks_taken = '$total_tricks' WHERE name IS '$team'"
 if [[ $total_tricks -ge $total_bid ]]; then
  sqlite3 playerbase.db "UPDATE teams SET score=score+'$total_bid'*10+('$total_tricks'-'$total_bid') WHERE name IS '$team'"
 else
  sqlite3 playerbase.db "UPDATE teams SET score=score-('$total_bid'*10) WHERE name IS '$team'"
 fi
 team_score=$(sqlite3 playerbase.db "SELECT score FROM teams WHERE name IS '$team'")
 echo "$team is at $team_score"
 done
 team_one_score=$(sqlite3 playerbase.db "SELECT score FROM teams WHERE rowID IS '1'")
 team_two_score=$(sqlite3 playerbase.db "SELECT score FROM teams WHERE rowID IS '2'")
}

sqlite3 playerbase.db "DROP TABLE players" && sqlite3 playerbase.db "DROP TABLE teams"
sqlite3 playerbase.db "CREATE TABLE IF NOT EXISTS players(name TEXT, bid INT, tricks_taken INT, team TEXT)"
sqlite3 playerbase.db "CREATE TABLE IF NOT EXISTS teams(name TEXT, total_bid INT, tricks_taken INT, score INT DEFAULT 0)"
gather_players
while [[ $team_one_score -lt 500 && $team_two_score -lt 500 ]]; do
set_dealer
accept_bid
calculate_scores
done
declare_winner
