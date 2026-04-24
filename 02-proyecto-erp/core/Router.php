<?php
namespace Core;

class Router
{
    private array $routes = [];

    public function get(string $path, callable|array $handler): void
    {
        $this->routes['GET'][$path] = $handler;
    }

    public function post(string $path, callable|array $handler): void
    {
        $this->routes['POST'][$path] = $handler;
    }

    public function group(string $prefix, callable $callback): void
    {
        $router = new self();
        $callback($router);
        foreach ($router->routes as $method => $routes) {
            foreach ($routes as $path => $handler) {
                $this->routes[$method][$prefix . $path] = $handler;
            }
        }
    }

    public function dispatch(): void
    {
        $method = $_SERVER['REQUEST_METHOD'];
        $uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
        $uri    = rtrim($uri, '/') ?: '/';

        $routes = $this->routes[$method] ?? [];

        foreach ($routes as $pattern => $handler) {
            $regex = preg_replace('/\{(\w+)\}/', '(?P<\1>[^/]+)', $pattern);
            $regex = '#^' . $regex . '$#';
            if (preg_match($regex, $uri, $matches)) {
                $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
                $this->call($handler, $params);
                return;
            }
        }

        http_response_code(404);
        require VIEWS_PATH . '/errors/404.php';
    }

    private function call(callable|array $handler, array $params): void
    {
        if (is_callable($handler)) {
            call_user_func_array($handler, $params);
        } elseif (is_array($handler) && count($handler) === 2) {
            [$class, $method] = $handler;
            $obj = new $class();
            call_user_func_array([$obj, $method], $params);
        }
    }
}
