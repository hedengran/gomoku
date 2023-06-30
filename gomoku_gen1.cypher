CALL {
    MATCH p = (start) ((a)-->(b) 
                    WHERE a.row = b.row AND a.column + 1 = b.column){4} (end) 
    RETURN p, start, end // horizontal
    UNION
    MATCH p = (start) ((a)-->(b) 
                    WHERE a.row + 1 = b.row AND a.column = b.column){4} (end) 
    RETURN p, start, end // vertical 
    UNION
    MATCH p = (start) ((a)-->(b) 
                    WHERE a.row + 1 = b.row AND a.column + 1 = b.column){4} (end) 
    RETURN p, start, end // diagonal, lr
    UNION
    MATCH p = (start) ((a)-->(b) 
                    WHERE a.row + 1 = b.row AND a.column - 1 = b.column){4} (end) 
    RETURN p, start, end // diagonal, rl 
} // all valid paths
WITH p WHERE all(node IN nodes(p) WHERE node.state IS NULL OR node.state = $symbol) OR 
             all(node IN nodes(p) WHERE node.state IS NULL OR node.state <> $symbol) // all open paths for either player
WITH p, 
    size([node IN nodes(p) WHERE node.state = $symbol]) + 2 AS myScore, // give each path a score based on how close it is to completion
    size([node IN nodes(p) WHERE node.state <> $symbol]) + 1 AS otherScore // give each path a score based on how close it is to completion
    // the two size filters above are enough, since any path including both symbols have already been excluded above
    // + 1 for score to value open paths above dead paths, + 2 to premier advancing my best path when tie.

MATCH (candidate WHERE candidate.state IS NULL)
    WHERE any(node IN nodes(p) WHERE node = candidate) // all nodes present in open paths
WITH candidate, 
     CASE
        WHEN myScore = 6 THEN 2    // 6 and 5 are compensated for + 2 and + 1 in above size-projection
        WHEN otherScore = 5 THEN 1
        ELSE 0
     END AS isWinningMove, // 2 means it's my win, 1 means that opponent wins in next move
     sum(myScore + otherScore) AS score 
     ORDER BY isWinningMove DESC, score DESC 
//RETURN candidate, isWinningMove, score
LIMIT 1

SET candidate.state = $symbol