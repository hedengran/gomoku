# Team Schuup  

A heuristic function for Gomoku (or 5-in-a-row), implemented as a Cypher query.

## Find all paths

```cypher
CALL {
    MATCH p = (start) ((a)-->(b) WHERE a.row = b.row AND a.column + 1 = b.column){4} (end) 
    OPTIONAL MATCH (before_start)-->(start) WHERE before_start.row = start.row AND before_start.column + 1 = start.column
    OPTIONAL MATCH (end)-->(after_end) WHERE end.row = after_end.row AND end.column + 1 = after_end.column
    RETURN p, start, end, before_start, after_end, 1 AS direction // horizontal
    UNION
    MATCH p = (start) ((a)-->(b) WHERE a.row + 1 = b.row AND a.column = b.column){4} (end) 
    OPTIONAL MATCH (before_start)-->(start) WHERE before_start.row + 1 = start.row AND before_start.column = start.column
    OPTIONAL MATCH (end)-->(after_end) WHERE end.row + 1 = after_end.row AND end.column = after_end.column
    RETURN p, start, end, before_start, after_end, 2 AS direction // vertical
    UNION
    MATCH p = (start) ((a)-->(b) WHERE a.row + 1 = b.row AND a.column + 1 = b.column){4} (end) 
    OPTIONAL MATCH (before_start)-->(start) WHERE before_start.row + 1 = start.row AND before_start.column + 1 = start.column
    OPTIONAL MATCH (end)-->(after_end) WHERE end.row + 1 = after_end.row AND end.column + 1 = after_end.column
    RETURN p, start, end, before_start, after_end, 3 AS direction // digonal, left-to-right
    UNION
    MATCH p = (start) ((a)-->(b) WHERE a.row + 1 = b.row AND a.column - 1 = b.column){4} (end) 
    OPTIONAL MATCH (before_start)-->(start) WHERE before_start.row + 1 = start.row AND before_start.column - 1 = start.column
    OPTIONAL MATCH (end)-->(after_end) WHERE end.row + 1 = after_end.row AND end.column - 1 = after_end.column
    RETURN p, start, end, before_start, after_end, 4 AS direction // diagonal, right-to-left
} // all valid paths

WITH *
    WHERE all(node IN nodes(p) WHERE node.state IS NULL OR node.state = $symbol) OR 
          all(node IN nodes(p) WHERE node.state IS NULL OR node.state <> $symbol) // exclude all paths that include both symbols since they cannot lead to victory
```

Could have been done a lot nicer, and would have avoided several bugs, had I looked at the actual data model (relationships track it's direction). This snippet from Satia Herfert does the same thing, but better looking and faster:

```
MATCH p = (start:Cell)-[r1]->()-[r2]->()-[r3]->()-[r4]->(end)
    WHERE r2.direction = r1.direction AND 
          r3.direction = r1.direction AND 
          r4.direction = r1.direction
OPTIONAL MATCH (before_start)-[r0]->(start)
    WHERE r0.direction = r1.direction
OPTIONAL MATCH (end)-[r5]->(after_end)
    WHERE r5.direction = r1.direction
```


## A simple score

```
WITH *, 
    size([node IN nodes(p) WHERE node.state = $symbol]) AS myScore, 
    size([node IN nodes(p) WHERE node.state <> $symbol]) AS otherScore
    // the two size filters above are enough, since any path including both symbols have already been excluded above
```

## Now let's look for easy winning moves

> ![Winning moves](http://gomokuworld.com/site/pictures/images/introduction_of_gomoku_006.gif)
_(source: [gomokuworld.com](http://gomokuworld.com/gomoku/1))_

```
WITH *,
CASE
    WHEN myScore = 4 THEN 2
    WHEN otherScore = 4 THEN 1
    ELSE 0
END AS isWinningMove, // 2 means it's my win, 1 means that opponent could win in next move

```

![Rows winnable in two moves](http://gomokuworld.com/site/pictures/images/introduction_of_gomoku_007.gif) 
_(source: [gomokuworld.com](http://gomokuworld.com/gomoku/1))_

Open-ended paths are paths which could eventually become lethal 4-in-rows.

```
WITH *,
    CASE
    WHEN before_start IS NOT NULL AND before_start.state IS NULL AND end.state IS NULL THEN 1
    WHEN start.state IS NULL AND after_end IS NOT NULL AND after_end.state IS NULL THEN 2
    ELSE 0
    END AS openEnded
```


```
CASE
    WHEN myScore = 3 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start)) THEN 2     
    WHEN otherScore = 3 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start)) THEN 1
    ELSE 0
END AS isThreeWinningMove,  
```

## What about forks?

![Alt text](http://gomokuworld.com/site/pictures/images/introduction_of_gomoku_009.gif) ![Alt text](http://gomokuworld.com/site/pictures/images/introduction_of_gomoku_010.gif) ![Alt text](http://gomokuworld.com/site/pictures/images/introduction_of_gomoku_011.gif)
_(source: [gomokuworld.com](http://gomokuworld.com/gomoku/1))_

```
CASE
    WHEN myScore = 3 THEN 1
    ELSE 0
END AS isMyThreeMove,
CASE
    WHEN otherScore = 3 THEN 1
    ELSE 0
END AS isOtherThreeMove, 
CASE
    WHEN myScore = 2 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start)) THEN 1
    ELSE 0
END AS isMyTwoMove,
CASE
    WHEN otherScore = 2 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start)) THEN 1
    ELSE 0
END AS isOtherTwoMove
```

## Aggregating everything

```
WITH candidate, 
    direction,
    max(isWinningMove) AS maxIsWinningMove,
    max(isThreeWinningMove) AS maxIsThreeWinningMove,
    max(isMyThreeMove) AS maxIsMyThreeMove,
    max(isOtherThreeMove) AS maxIsOtherThreeMove,
    max(isMyTwoMove) AS maxIsMyTwoMove,
    max(isOtherTwoMove) AS maxIsOtherTwoMove,
    sum((myScore + otherScore + toInteger(openEnded > 0))) AS candidateScore // give an additional point for open-ended paths, as a heuristic

WITH candidate, 
    sum(maxIsWinningMove) AS isWinningMove,
    sum(maxIsThreeWinningMove) AS isThreeWinningMove,
    sum(maxIsMyThreeMove) AS isMyThreeMoveSum,
    sum(maxIsOtherThreeMove) AS isOtherThreeMoveSum,
    sum(maxIsMyTwoMove) AS isMyTwoMoveSum,
    sum(maxIsOtherTwoMove) AS isOtherTwoMoveSum,
    sum(candidateScore) + count(*) AS score // give one point extra for each direction that a candidate advances play in, as a heuristic
```

## Find forks

```
WITH *,
CASE
    WHEN isMyThreeMoveSum >= 2 THEN 2
    WHEN isOtherThreeMoveSum >= 2 THEN 1
    WHEN isMyThreeMoveSum > 0 AND isMyTwoMoveSum > 0 THEN 2
    WHEN isOtherThreeMoveSum > 0 AND isOtherTwoMoveSum > 0 THEN 1
    WHEN isMyTwoMoveSum  >= 2 THEN 2
    WHEN isOtherTwoMoveSum  >= 2 THEN 1
    ELSE 0
END AS isFork
```

## Find best move

```
WITH * ORDER BY isWinningMove DESC, isThreeWinningMove DESC, isFork DESC, score DESC 
LIMIT 1
RETURN candidate
```