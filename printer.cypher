CALL {
    CALL {
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row = b.row AND a.column + 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
            WHERE before_start.row = start.row AND before_start.column + 1 = start.column
        OPTIONAL MATCH (end)-->(after_end)
            WHERE end.row = after_end.row AND end.column + 1 = after_end.column
        RETURN p, start, end, before_start, after_end, 1 AS direction
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
            WHERE before_start.row + 1 = start.row AND before_start.column = start.column
        OPTIONAL MATCH (end)-->(after_end)
            WHERE end.row + 1 = after_end.row AND end.column = after_end.column
        RETURN p, start, end, before_start, after_end, 2 AS direction
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column + 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
            WHERE before_start.row + 1 = start.row AND before_start.column + 1 = start.column
        OPTIONAL MATCH (end)-->(after_end)
            WHERE end.row + 1 = after_end.row AND end.column + 1 = after_end.column
        RETURN p, start, end, before_start, after_end, 3 AS direction
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column - 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
            WHERE before_start.row + 1 = start.row AND before_start.column - 1 = start.column
        OPTIONAL MATCH (end)-->(after_end)
            WHERE end.row + 1 = after_end.row AND end.column - 1 = after_end.column
        RETURN p, start, end, before_start, after_end, 4 AS direction
    } // all valid paths
    WITH *
        WHERE all(node IN nodes(p) WHERE node.state IS NULL OR node.state = $symbol) OR 
            all(node IN nodes(p) WHERE node.state IS NULL OR node.state <> $symbol) // all open paths for either player

    WITH *,
        CASE
        WHEN before_start IS NOT NULL AND before_start.state IS NULL AND end.state IS NULL THEN 1
        WHEN start.state IS NULL AND after_end IS NOT NULL AND after_end.state IS NULL THEN 2
        WHEN before_start IS NOT NULL AND before_start.state IS NULL AND after_end IS NOT NULL AND after_end.state IS NULL THEN 3
        ELSE 0
        END AS openEnded

    WITH *,
        CASE
        WHEN before_start IS NOT NULL AND before_start.state IS NULL AND after_end IS NOT NULL AND after_end.state IS NULL THEN 1
        WHEN before_start IS NOT NULL AND before_start.state IS NULL AND end.state IS NULL THEN 1
        WHEN start.state IS NULL AND after_end IS NOT NULL AND after_end.state IS NULL THEN 2
        ELSE 0
        END AS openEndedVal

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
        WHEN myScore = 3 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start) OR openEnded = 3) THEN 2
        WHEN otherScore = 3 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start) OR openEnded = 3) THEN 1
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
        WHEN myScore = 2 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start) OR (openEnded = 3)) THEN 1
        ELSE 0
    END AS isMyTwoMove,
    CASE
        WHEN otherScore = 2 AND ((openEnded = 1 AND candidate <> end) OR (openEnded = 2 AND candidate <> start) OR (openEnded = 3)) THEN 1
        ELSE 0
    END AS isOtherTwoMove

    WITH candidate, 
        direction, 
        max(isWinningMove) AS maxIsWinningMove,
        max(isThreeWinningMove) AS maxIsThreeWinningMove,
        max(isMyThreeMove) AS maxIsMyThreeMove,
        max(isOtherThreeMove) AS maxIsOtherThreeMove,
        max(isMyTwoMove) AS maxIsMyTwoMove,
        max(isOtherTwoMove) AS maxIsOtherTwoMove,
        sum((myScore + otherScore + openEndedVal)) AS candidateScore

    WITH candidate, 
        sum(maxIsWinningMove) AS isWinningMove,
        sum(maxIsThreeWinningMove) AS isThreeWinningMove,
        sum(maxIsMyThreeMove) AS isMyThreeMoveSum,
        sum(maxIsOtherThreeMove) AS isOtherThreeMoveSum,
        sum(maxIsMyTwoMove) AS isMyTwoMoveSum,
        sum(maxIsOtherTwoMove) AS isOtherTwoMoveSum,
        sum(candidateScore) AS score,
        count(*) AS dirs


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

    WITH * ORDER BY isWinningMove DESC, isThreeWinningMove DESC, isFork DESC, score + dirs DESC
    LIMIT 1
    RETURN candidate, score

    UNION 

    // When the game will for sure end in a tie we still need to update the game

    MATCH (candidate) WHERE candidate.state IS NULL
    WITH candidate, 0 AS score LIMIT 1
    RETURN candidate, score
}

WITH candidate ORDER BY score DESC LIMIT 1
SET candidate.state = $symbol

// 8-x