CALL {
    CALL {
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row = b.row AND a.column + 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end // horizontal
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end // vertical 
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column + 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end // diagonal, lr
        UNION
        MATCH p = (start) ((a)-->(b) 
                        WHERE a.row + 1 = b.row AND a.column - 1 = b.column){4} (end) 
        OPTIONAL MATCH (before_start)-->(start)
        OPTIONAL MATCH (end)-->(after_end)
        RETURN p, start, end, before_start, after_end // diagonal, rl 
    } // all valid paths
    WITH p,
        CASE
        WHEN before_start.state IS NULL AND end.state IS NULL THEN 1
        WHEN start.state IS NULL AND after_end.state IS NULL THEN 1
        ELSE 0
        END AS openended
    WHERE all(node IN nodes(p) WHERE node.state IS NULL OR node.state = $symbol) OR 
                all(node IN nodes(p) WHERE node.state IS NULL OR node.state <> $symbol) // all open paths for either player
    WITH p, 
        openended,
        size([node IN nodes(p) WHERE node.state = $symbol]) AS myScore, // give each path a score based on how close it is to completion
        size([node IN nodes(p) WHERE node.state <> $symbol]) AS otherScore // give each path a score based on how close it is to completion
        // the two size filters above are enough, since any path including both symbols have already been excluded above

    UNWIND nodes(p) AS candidate 
    WITH * WHERE candidate.state IS NULL
    WITH candidate, 
        CASE
            WHEN myScore = 4 THEN 2    // 6 and 5 are compensated for + 2 and + 1 in above size-projection
            WHEN otherScore = 4 THEN 1
            ELSE 0
        END AS isWinningMove, // 2 means it's my win, 1 means that opponent wins in next move
        CASE
            WHEN myScore = 3 AND openended = 1 THEN 2
            WHEN otherScore = 3 AND openended = 1 THEN 1
            ELSE 0
        END AS isThreeWinningMove, 
        sum(myScore + otherScore) AS score 
        ORDER BY isWinningMove DESC, isThreeWinningMove DESC, score DESC 
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