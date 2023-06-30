MATCH (backup WHERE backup.state IS NULL) 
WITH backup 
LIMIT 1
CALL {
    MATCH p = (start) ((a WHERE a.state IS NULL OR a.state = $symbol)-->(b WHERE b.state IS NULL OR b.state = $symbol) 
                    WHERE a.row = b.row AND a.column + 1 = b.column){4} (end) 
    RETURN p, start, end // horizontal
    UNION
    MATCH p = (start) ((a WHERE a.state IS NULL OR a.state = $symbol)-->(b WHERE b.state IS NULL OR b.state = $symbol) 
                    WHERE a.row + 1 = b.row AND a.column = b.column){4} (end) 
    RETURN p, start, end // vertical 
    UNION
    MATCH p = (start) ((a WHERE a.state IS NULL OR a.state = $symbol)-->(b WHERE b.state IS NULL OR b.state = $symbol) 
                    WHERE a.row + 1 = b.row AND a.column + 1 = b.column){4} (end) 
    RETURN p, start, end // diagonal, lr
    UNION
    MATCH p = (start) ((a WHERE a.state IS NULL OR a.state = $symbol)-->(b WHERE b.state IS NULL OR b.state = $symbol) 
                    WHERE a.row + 1 = b.row AND a.column - 1 = b.column){4} (end) 
    RETURN p, start, end // diagonal, rl 
} // all valid paths
WITH p, 
    size([node IN nodes(p) WHERE node.state = $symbol]) + 1 AS count, // give each path a score based on how close it is to completion
    backup

MATCH (candidate WHERE candidate.state IS NULL)
    WHERE any(node IN nodes(p) WHERE node = candidate) // all nodes present in valid paths
WITH candidate, sum(count) AS score, backup ORDER BY score DESC 
LIMIT 1

WITH CASE 
    WHEN candidate IS NULL THEN backup
    ELSE candidate
END AS finalNode

SET finalNode.state = $symbol