// Made by MexrlDev after some time of studying netflix to find out everything....
// Under MIT License use it as you like.

(function() {
    // ---------- Game settings ----------
    var GRID = 20;
    var COLS = Math.floor(1280 / GRID);   // 64
    var ROWS = Math.floor(720 / GRID);    // 36
    var SPEED = 150;                      // ms per move

    // ---------- Game state ----------
    var snake = [];
    var food  = null;
    var dir   = { x: 1, y: 0 };
    var next  = { x: 1, y: 0 };
    var score = 0;
    var alive = false;
    var paused = false;
    var timer = null;

    var overlay, scoreText, overText, pauseText, restartHint;
    var snakeW = [], foodW = null;

    // ---------- Helpers ----------
    function wrap(v, m) { return ((v % m) + m) % m; }

    function mkWidget(x, y, w, h, col, parent) {
        var wgt = nrdp.gibbon.makeWidget();
        wgt.x = x; wgt.y = y; wgt.width = w; wgt.height = h;
        wgt.color = col;
        if (parent) wgt.parent = parent;
        return wgt;
    }

    function cell(x, y, col) {
        return mkWidget(x * GRID, y * GRID, GRID, GRID, col, overlay);
    }

    // ---------- Create scene (1280×720) ----------
    overlay = nrdp.gibbon.makeWidget();
    overlay.color  = { r: 0, g: 0, b: 0, a: 255 };
    overlay.width  = 1280;
    overlay.height = 720;
    nrdp.gibbon.scene.widget = overlay;

    scoreText = mkWidget(10, 690, 250, 25,
                         { r: 255, g: 255, b: 255, a: 0 }, overlay);
    scoreText.text = "Score: 0";
    scoreText.textStyle = { size: 20, color: { r: 255, g: 255, b: 255 } };

    overText = mkWidget(200, 280, 880, 80,
                        { r: 0, g: 0, b: 0, a: 0 }, overlay);
    overText.text = "";
    overText.textStyle = { size: 36, color: { r: 255, g: 0, b: 0 },
                           align: "center" };
    overText.visible = false;

    restartHint = mkWidget(200, 360, 880, 40,
                           { r: 0, g: 0, b: 0, a: 0 }, overlay);
    restartHint.text = "";
    restartHint.textStyle = { size: 20, color: { r: 255, g: 255, b: 255 },
                              align: "center" };
    restartHint.visible = false;

    pauseText = mkWidget(300, 300, 680, 80,
                         { r: 0, g: 0, b: 0, a: 0 }, overlay);
    pauseText.text = "PAUSE";
    pauseText.textStyle = { size: 48, color: { r: 255, g: 255, b: 255 },
                            align: "center" };
    pauseText.visible = false;

    // ---------- Food ----------
    function placeFood() {
        if (foodW) { foodW.visible = false; foodW = null; }
        var occupied = {};
        for (var i = 0; i < snake.length; i++)
            occupied[snake[i].x + ',' + snake[i].y] = true;

        var free = [];
        for (var x = 0; x < COLS; x++)
            for (var y = 0; y < ROWS; y++)
                if (!occupied[x + ',' + y]) free.push({ x: x, y: y });

        if (free.length === 0) { win(); return; }

        var pos = free[Math.floor(Math.random() * free.length)];
        food = pos;
        foodW = cell(pos.x, pos.y, { r: 255, g: 0, b: 0, a: 255 });
        foodW.visible = !paused;
    }

    // ---------- Pause / Resume ----------
    function setPause(p) {
        if (paused === p) return;
        paused = p;
        if (p) {
            for (var i = 0; i < snakeW.length; i++) snakeW[i].visible = false;
            if (foodW) foodW.visible = false;
            pauseText.visible = true;
        } else {
            for (var i = 0; i < snakeW.length; i++) snakeW[i].visible = true;
            if (foodW) foodW.visible = true;
            pauseText.visible = false;
        }
    }

    // ---------- Game flow ----------
    function start() {
        if (timer) nrdp.clearInterval(timer);
        for (var i = 0; i < snakeW.length; i++) snakeW[i].visible = false;
        snakeW = [];
        if (foodW) { foodW.visible = false; foodW = null; }
        overText.visible = false;
        restartHint.visible = false;
        pauseText.visible = false;
        paused = false;

        snake = [];
        var sx = Math.floor(COLS / 2), sy = Math.floor(ROWS / 2);
        for (var i = 0; i < 5; i++) snake.push({ x: sx - i, y: sy });
        dir  = { x: 1, y: 0 };
        next = { x: 1, y: 0 };
        score = 0;
        alive = true;

        for (var s = 0; s < snake.length; s++)
            snakeW.push(cell(snake[s].x, snake[s].y,
                             { r: 0, g: 255, b: 0, a: 255 }));

        placeFood();
        scoreText.text = "Score: 0";
        timer = nrdp.setInterval(step, SPEED);
    }

    function step() {
        if (!alive || paused) return;
        dir = next;

        var head = snake[0];
        var newHead = {
            x: wrap(head.x + dir.x, COLS),
            y: wrap(head.y + dir.y, ROWS)
        };

        for (var i = 0; i < snake.length - 1; i++)
            if (snake[i].x === newHead.x && snake[i].y === newHead.y) { over(); return; }

        snake.unshift(newHead);

        if (food && newHead.x === food.x && newHead.y === food.y) {
            score++;
            scoreText.text = "Score: " + score;
            food = null;
            if (foodW) { foodW.visible = false; foodW = null; }
            placeFood();
        } else {
            snake.pop();
        }

        while (snakeW.length > snake.length) {
            var ex = snakeW.pop(); ex.visible = false;
        }
        for (var s = 0; s < snake.length; s++) {
            var seg = snake[s];
            if (s < snakeW.length) {
                var w = snakeW[s];
                w.x = seg.x * GRID; w.y = seg.y * GRID; w.visible = true;
            } else {
                snakeW.push(cell(seg.x, seg.y,
                                 { r: 0, g: 255, b: 0, a: 255 }));
            }
        }
    }

    function over() {
        alive = false;
        if (timer) nrdp.clearInterval(timer);
        overText.text = "GAME OVER";
        overText.visible = true;
        restartHint.text = "Press X to restart";
        restartHint.visible = true;
    }

    function win() {
        alive = false;
        if (timer) nrdp.clearInterval(timer);
        overText.text = "YOU WIN!";
        overText.visible = true;
        restartHint.text = "Press X to restart";
        restartHint.visible = true;
    }

    // ---------- BLOCK Netflix "Try Again" (so X doesn't reload the app) ----------
    if (typeof util !== 'undefined' && util.changeLocation) {
        // Save the original (we'll never call it, but just in case)
        var _origChangeLocation = util.changeLocation;
        util.changeLocation = function(url) {
            // Do nothing – this prevents Netflix from reloading the app when X is pressed.
            // We'll handle the X press via our native key listener instead.
            throw new Error('X pressed (handled by game)');
        };
    }

    // ---------- Input (native Netflix API) ----------
    nrdp.gibbon.addEventListener('key', function(e) {
        if (e.data.type !== 'press') return;
        var ui = e.data.uiEvent;

        // Toggle pause with Circle
        if (ui === 'key.back') {
            if (alive) {
                setPause(!paused);
            }
            return;
        }

        // Restart with Cross – only when game is over
        if (ui === 'key.enter') {
            if (!alive) {
                start();
            }
            return;
        }

        // Movement only when alive and not paused
        if (!alive || paused) return;

        if (ui === 'key.up'    && dir.y !== 1)  next = { x: 0, y: -1 };
        if (ui === 'key.down'  && dir.y !== -1) next = { x: 0, y:  1 };
        if (ui === 'key.left'  && dir.x !== 1)  next = { x: -1,y:  0 };
        if (ui === 'key.right' && dir.x !== -1) next = { x: 1, y:  0 };
    });

    start();
})();
