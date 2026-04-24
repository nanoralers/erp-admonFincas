<?php
namespace Core;

use PDO;
use PDOException;
use RuntimeException;

class Database
{
    private static ?self $instance = null;
    private PDO $pdo;

    private function __construct()
    {
        $dsn = sprintf('mysql:host=%s;port=%s;dbname=%s;charset=%s', DB_HOST, DB_PORT, DB_NAME, DB_CHARSET);
        try {
            $this->pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
                PDO::MYSQL_ATTR_FOUND_ROWS   => true,
            ]);
        } catch (PDOException $e) {
            throw new RuntimeException('DB Connection failed: ' . $e->getMessage(), 500);
        }
    }

    public static function getInstance(): self
    {
        if (self::$instance === null) self::$instance = new self();
        return self::$instance;
    }

    public function pdo(): PDO { return $this->pdo; }

    public function query(string $sql, array $p = []): array
    {
        $s = $this->pdo->prepare($sql); $s->execute($p); return $s->fetchAll();
    }

    public function queryOne(string $sql, array $p = []): ?array
    {
        $s = $this->pdo->prepare($sql); $s->execute($p);
        return $s->fetch() ?: null;
    }

    public function execute(string $sql, array $p = []): int
    {
        $s = $this->pdo->prepare($sql); $s->execute($p); return $s->rowCount();
    }

    public function insert(string $sql, array $p = []): string
    {
        $this->execute($sql, $p); return $this->pdo->lastInsertId();
    }

    public function beginTransaction(): void { $this->pdo->beginTransaction(); }
    public function commit(): void           { $this->pdo->commit(); }
    public function rollBack(): void         { $this->pdo->rollBack(); }

    public function paginate(string $sql, array $p = [], int $page = 1, int $perPage = 25): array
    {
        $countSql = 'SELECT COUNT(*) as total FROM (' . $sql . ') _c';
        $total    = (int)($this->queryOne($countSql, $p)['total'] ?? 0);
        $offset   = ($page - 1) * $perPage;
        $rows     = $this->query($sql . " LIMIT $perPage OFFSET $offset", $p);
        return [
            'data'         => $rows,
            'total'        => $total,
            'per_page'     => $perPage,
            'current_page' => $page,
            'last_page'    => (int)ceil($total / $perPage),
        ];
    }
}
