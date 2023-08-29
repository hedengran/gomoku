CALL {
    CALL {
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row = b.row AND a.column + 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end, "h" AS direction // horizontal
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end, "v" AS direction // vertical 
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column + 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end, "dlr" AS direction // diagonal, lr
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column - 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end, "drl" AS direction // diagonal, rl 
    } // all valid paths
    WITH *,
        CASE
        WHEN before_start.state IS NULL AND end.state IS NULL THEN 1
        WHEN start.state IS NULL AND after_end.state IS NULL THEN 1
        ELSE 0
        END AS openIfFour,
        CASE
        WHEN start.state IS NULL AND end.state IS NULL THEN 1
        ELSE 0
        END AS openIfThree
    WHERE all(node IN nodes(p) WHERE node.state IS NULL OR node.state = $symbol) OR 
                all(node IN nodes(p) WHERE node.state IS NULL OR node.state <> $symbol) // all open paths for either player
    WITH *, 
         size([node IN nodes(p) WHERE node.state = $symbol]) AS myScore, // give each path a score based on how close it is to completion
         size([node IN nodes(p) WHERE node.state <> $symbol]) AS otherScore // give each path a score based on how close it is to completion
         // the two size filters above are enough, since any path including both symbols have already been excluded above

    UNWIND nodes(p) AS candidate 
    WITH * WHERE candidate.state IS NULL

    WITH *, 
        CASE
            WHEN myScore = 4 THEN 2
            WHEN otherScore = 4 THEN 1
            ELSE 0
        END AS isWinningMove, // 2 means it's my win, 1 means that opponent wins in next move
        CASE
            WHEN myScore = 3 AND  openIfFour = 1 THEN 2
            WHEN otherScore = 3 AND  openIfFour = 1 THEN 1
            ELSE 0
        END AS isThreeWinningMove, 
        CASE
            WHEN myScore = 3 THEN 1
            ELSE 0
        END AS isMyThreeMove, 
        CASE
            WHEN otherScore = 3 THEN 1
            ELSE 0
        END AS isOtherThreeMove, 
        CASE
            WHEN myScore = 2 AND openIfThree = 1 AND candidate <> start AND candidate <> end THEN 1
            ELSE 0
        END AS isMyTwoMove,
        CASE
            WHEN otherScore = 2 AND openIfThree = 1 AND candidate <> start AND candidate <> end THEN 1
            ELSE 0
        END AS isOtherTwoMove

    WITH
        candidate, 
        collect(DISTINCT direction) AS directions,
        sum(isWinningMove) As winningMoveSum, 
        sum(isThreeWinningMove) AS isThreeWinningMoveSum, 
        sum(isMyThreeMove) AS isMyThreeMoveSum,
        sum(isOtherThreeMove) AS isOtherThreeMoveSum,
        sum(isMyTwoMove) AS isMyTwoMoveSum,
        sum(isOtherTwoMove) AS isOtherTwoMoveSum,
        sum(myScore + otherScore + 1) AS scoreSum, // +1 value paths with no symbols
        count(*) AS count
    WITH *,
    CASE
        WHEN isMyThreeMoveSum >= 2 AND directions >= 2 THEN 2
        WHEN isOtherThreeMoveSum >= 2 AND directions >= 2 THEN 1
        WHEN isMyThreeMoveSum > 0 AND isMyTwoMoveSum > 0 AND directions >= 2 THEN 2
        WHEN isOtherThreeMoveSum > 0 AND isOtherTwoMoveSum > 0 AND directions >= 2 THEN 1
        WHEN isMyTwoMoveSum  >= 2 AND directions >= 2 THEN 2
        WHEN isOtherTwoMoveSum  >= 2 AND directions >= 2 THEN 2
        ELSE 0
    END AS isFork

    WITH * ORDER BY winningMoveSum DESC, isThreeWinningMoveSum DESC, isFork DESC, scoreSum DESC, count DESC
    LIMIT 1
    RETURN candidate, scoreSum

    UNION 

    // When the game will for sure end in a tie we still need to update the game

    MATCH (candidate) WHERE candidate.state IS NULL
    WITH candidate, 0 AS scoreSum LIMIT 1
    RETURN candidate, scoreSum
}

WITH candidate ORDER BY scoreSum DESC LIMIT 1
SET candidate.state = $symbol