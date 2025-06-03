import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(SpaceShooterApp());
}

class SpaceShooterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '太空战争：三大Boss挑战',
      theme: ThemeData.dark(),
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 数据持久化管理
class GameData {
  static int maxScore = 0;
  static int unlockedLevel = 1;
  static int totalKills = 0;
  static int bossesDefeated = 0;
  static Map<String, bool> achievements = {
    'first_boss': false,
    'second_boss': false,
    'final_boss': false,
    'score_1000': false,
    'score_5000': false,
    'weapon_master': false,
  };
  
  static void saveData() {
    // 模拟数据保存（在真实环境中会使用SharedPreferences）
    print('游戏数据已保存 - 最高分: $maxScore, 解锁关卡: $unlockedLevel');
  }
  
  static void loadData() {
    // 模拟数据加载
    print('游戏数据已加载');
  }
  
  static void unlockAchievement(String key) {
    if (!achievements[key]!) {
      achievements[key] = true;
      print('🏆 成就解锁: $key');
    }
  }
}

// 音效管理系统
class SoundManager {
  static bool soundEnabled = true;
  
  static void playSound(String soundName) {
    if (!soundEnabled) return;
    
    // 模拟音效播放（在真实环境中会使用audioplayers插件）
    switch (soundName) {
      case 'shoot':
        HapticFeedback.selectionClick();
        print('🔊 射击音效');
        break;
      case 'explosion':
        HapticFeedback.mediumImpact();
        print('🔊 爆炸音效');
        break;
      case 'boss_hit':
        HapticFeedback.heavyImpact();
        print('🔊 Boss受伤音效');
        break;
      case 'power_up':
        HapticFeedback.lightImpact();
        print('🔊 道具音效');
        break;
      case 'level_complete':
        HapticFeedback.heavyImpact();
        print('🔊 关卡完成音效');
        break;
      case 'boss_death':
        print('🔊 Boss死亡音效');
        break;
    }
  }
  
  static void playBGM(String bgmName) {
    if (!soundEnabled) return;
    print('🎵 播放背景音乐: $bgmName');
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late AnimationController _gameController;
  late AnimationController _starController;
  late AnimationController _shakeController;
  late AnimationController _3dController;
  late Timer _gameTimer;
  late Timer _shootTimer;
  
  // 3D变换效果
  double perspectiveX = 0;
  double perspectiveY = 0;
  double cameraShake = 0;
  
  // 游戏状态
  bool gameStarted = false;
  bool gameOver = false;
  bool bossMode = false;
  bool levelTransition = false;
  int score = 0;
  int currentLevel = 1;
  int playerHealth = 100;
  int bossHealth = 500;
  
  // 关卡系统
  List<BossData> bosses = [
    BossData('吾尔克西江', '闪电之主', Colors.blue, 500, 1),
    BossData('木斯塔帕江', '烈火战神', Colors.red, 750, 2),
    BossData('司马义江', '终极帝王', Colors.purple, 1000, 3),
  ];
  
  // 屏幕震动
  double shakeOffsetX = 0;
  double shakeOffsetY = 0;
  
  // 武器系统
  int weaponLevel = 0;
  int weaponUpgradePoints = 0;
  List<String> weaponNames = ['单发', '双发', '三发', '散弹', '激光炮', '等离子炮'];
  
  // 技能系统
  bool timeSlowActive = false;
  bool invincibleActive = false;
  bool megaBlastReady = true;
  int timeSlowCooldown = 0;
  int invincibleCooldown = 0;
  int megaBlastCooldown = 0;
  bool shieldActive = false;
  int shieldCooldown = 0;
  int shieldDuration = 0;

  int comboCount = 0;
  int comboTimer = 0;

  final ParticlePool particlePool = ParticlePool();
  
  // 游戏对象
  Player player = Player();
  List<Enemy> enemies = [];
  List<Bullet> bullets = [];
  List<EnemyBullet> enemyBullets = [];
  List<Star> stars = [];
  List<Explosion> explosions = [];
  List<PowerUp> powerUps = [];
  List<Particle> particles = [];
  List<Planet> planets = [];
  List<SpaceDebris> debris = [];
  List<Nebula> nebulas = [];
  List<LevelTransitionEffect> transitionEffects = [];
  
  // Boss相关
  Boss? boss;
  bool bossSpawned = false;
  int bossPhase = 0;
  
  Random random = Random();

  @override
  void initState() {
    super.initState();
    _gameController = AnimationController(
      duration: Duration(milliseconds: 16),
      vsync: this,
    );
    _starController = AnimationController(
      duration: Duration(milliseconds: 50),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _3dController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    
    GameData.loadData();
    initializeBackground();
    _gameController.addListener(updateGame);
    _starController.addListener(updateStars);
    _3dController.addListener(update3DEffects);
    _starController.repeat();
    _3dController.repeat();
  }

  void update3DEffects() {
    setState(() {
      perspectiveX = sin(_3dController.value * 2 * pi) * 2;
      perspectiveY = cos(_3dController.value * 2 * pi) * 1;
    });
  }

  void initializeBackground() {
    stars.clear();
    planets.clear();
    debris.clear();
    nebulas.clear();
    
    // 星星 - 根据关卡调整颜色
    Color starColor = _getLevelColor();
    for (int i = 0; i < 250; i++) {
      stars.add(Star(
        x: random.nextDouble() * 400,
        y: random.nextDouble() * 800,
        speed: random.nextDouble() * 5 + 1,
        brightness: random.nextDouble(),
        size: random.nextDouble() * 2.5 + 0.5,
        twinkle: random.nextDouble() * 2 * pi,
        color: starColor,
      ));
    }
    
    // 行星 - 关卡主题
    List<Color> levelColors = _getLevelColors();
    for (int i = 0; i < 4; i++) {
      planets.add(Planet(
        x: random.nextDouble() * 500,
        y: random.nextDouble() * 800,
        radius: random.nextDouble() * 40 + 25,
        speed: random.nextDouble() * 0.8 + 0.3,
        color: levelColors[random.nextInt(levelColors.length)],
        rings: random.nextBool(),
      ));
    }
    
    // 太空碎片
    for (int i = 0; i < 20; i++) {
      debris.add(SpaceDebris(
        x: random.nextDouble() * 400,
        y: random.nextDouble() * 800,
        size: random.nextDouble() * 10 + 3,
        speed: random.nextDouble() * 3 + 0.8,
        rotation: random.nextDouble() * 2 * pi,
        rotationSpeed: random.nextDouble() * 0.15 - 0.075,
      ));
    }
    
    // 星云 - 关卡氛围
    for (int i = 0; i < 6; i++) {
      nebulas.add(Nebula(
        x: random.nextDouble() * 500,
        y: random.nextDouble() * 900,
        size: random.nextDouble() * 120 + 60,
        speed: random.nextDouble() * 0.4 + 0.15,
        color: levelColors[random.nextInt(levelColors.length)],
        pulse: random.nextDouble() * 2 * pi,
      ));
    }
  }

  Color _getLevelColor() {
    switch (currentLevel) {
      case 1: return Colors.blue;
      case 2: return Colors.red;
      case 3: return Colors.purple;
      default: return Colors.white;
    }
  }

  List<Color> _getLevelColors() {
    switch (currentLevel) {
      case 1: return [Colors.blue, Colors.cyan, Colors.lightBlue];
      case 2: return [Colors.red, Colors.orange, Colors.deepOrange];
      case 3: return [Colors.purple, Colors.pink, Colors.deepPurple];
      default: return [Colors.white, Colors.grey, Colors.blueGrey];
    }
  }

  void startGame() {
    setState(() {
      gameStarted = true;
      gameOver = false;
      levelTransition = false;
      score = 0;
      currentLevel = 1;
      playerHealth = 100;
      bossHealth = bosses[0].health;
      bossMode = false;
      bossSpawned = false;
      bossPhase = 0;
      weaponLevel = 0;
      weaponUpgradePoints = 0;
      timeSlowActive = false;
      invincibleActive = false;
      megaBlastReady = true;
      timeSlowCooldown = 0;
      invincibleCooldown = 0;
      megaBlastCooldown = 0;
      shieldActive = false;
      shieldCooldown = 0;
      shieldDuration = 0;
      comboCount = 0;
      comboTimer = 0;
      enemies.clear();
      bullets.clear();
      enemyBullets.clear();
      explosions.clear();
      powerUps.clear();
      particles.clear();
      transitionEffects.clear();
      boss = null;
      player = Player();
    });
    
    SoundManager.playBGM('level_1');
    initializeBackground();
    _gameController.repeat();
    
    _shootTimer = Timer.periodic(Duration(milliseconds: timeSlowActive ? 300 : 120), (timer) {
      if (!gameOver && gameStarted && !levelTransition) {
        autoShoot();
      }
    });
    
    _gameTimer = Timer.periodic(Duration(milliseconds: timeSlowActive ? 32 : 16), (timer) {
      if (!gameOver && !levelTransition) {
        spawnEnemies();
        checkBossSpawn();
        updateCooldowns();
      }
    });
  }

  void autoShoot() {
    SoundManager.playSound('shoot');
    
    switch (weaponLevel) {
      case 0: // 单发
        bullets.add(Bullet(x: player.x, y: player.y - 20, type: 0));
        break;
      case 1: // 双发
        bullets.add(Bullet(x: player.x - 8, y: player.y - 20, type: 0));
        bullets.add(Bullet(x: player.x + 8, y: player.y - 20, type: 0));
        break;
      case 2: // 三发
        bullets.add(Bullet(x: player.x, y: player.y - 20, type: 0));
        bullets.add(Bullet(x: player.x - 12, y: player.y - 15, type: 0));
        bullets.add(Bullet(x: player.x + 12, y: player.y - 15, type: 0));
        break;
      case 3: // 散弹
        for (int i = 0; i < 5; i++) {
          bullets.add(Bullet(
            x: player.x + (i - 2) * 6,
            y: player.y - 20,
            type: 1,
            angle: (i - 2) * 0.3,
          ));
        }
        break;
      case 4: // 激光炮
        bullets.add(Bullet(x: player.x, y: player.y - 20, type: 2));
        break;
      case 5: // 等离子炮
        bullets.add(Bullet(x: player.x, y: player.y - 20, type: 3));
        for (int i = 0; i < 2; i++) {
          bullets.add(Bullet(
            x: player.x + (i == 0 ? -15 : 15),
            y: player.y - 15,
            type: 2,
          ));
        }
        break;
    }
    
    // 射击粒子效果
    for (int i = 0; i < 6; i++) {
      particles.add(particlePool.obtain(
        x: player.x + random.nextDouble() * 20 - 10,
        y: player.y - 15,
        vx: random.nextDouble() * 4 - 2,
        vy: random.nextDouble() * -4 - 1,
        color: _getLevelColor(),
        life: 25,
      ));
    }
  }

  void updateCooldowns() {
    if (timeSlowCooldown > 0) timeSlowCooldown--;
    if (invincibleCooldown > 0) invincibleCooldown--;
    if (megaBlastCooldown > 0) megaBlastCooldown--;
    if (shieldCooldown > 0) shieldCooldown--;
    if (shieldActive && shieldDuration > 0) shieldDuration--;
    if (shieldActive && shieldDuration <= 0) {
      shieldActive = false;
      shieldCooldown = 600;
      shieldDuration = 300;
    }

    if (comboTimer > 0) {
      comboTimer--;
    } else {
      comboCount = 0;
    }
    
    if (timeSlowActive && timeSlowCooldown <= 0) {
      timeSlowActive = false;
      timeSlowCooldown = 300;
    }
    
    if (invincibleActive && invincibleCooldown <= 0) {
      invincibleActive = false;
      invincibleCooldown = 600;
    }
  }

  void triggerScreenShake(double intensity) {
    _shakeController.reset();
    _shakeController.forward().then((_) {
      setState(() {
        shakeOffsetX = 0;
        shakeOffsetY = 0;
        cameraShake = 0;
      });
    });
    
    _shakeController.addListener(() {
      setState(() {
        shakeOffsetX = (random.nextDouble() - 0.5) * intensity * (1 - _shakeController.value);
        shakeOffsetY = (random.nextDouble() - 0.5) * intensity * (1 - _shakeController.value);
        cameraShake = intensity * (1 - _shakeController.value);
      });
    });
    
    HapticFeedback.heavyImpact();
  }

  void useSkill(int skillType) {
    switch (skillType) {
      case 0: // 时间减慢
        if (timeSlowCooldown <= 0) {
          timeSlowActive = true;
          timeSlowCooldown = 180;
          HapticFeedback.mediumImpact();
        }
        break;
      case 1: // 无敌冲刺
        if (invincibleCooldown <= 0) {
          invincibleActive = true;
          invincibleCooldown = 120;
          HapticFeedback.mediumImpact();
        }
        break;
      case 2: // 清屏大招
        if (megaBlastCooldown <= 0) {
          megaBlast();
          megaBlastCooldown = 1000;
          HapticFeedback.heavyImpact();
        }
        break;
      case 3: // 能量护盾
        if (shieldCooldown <= 0) {
          shieldActive = true;
          shieldDuration = 300;
          HapticFeedback.mediumImpact();
        }
        break;
    }
  }

  void megaBlast() {
    SoundManager.playSound('explosion');
    triggerScreenShake(25);
    
    for (var enemy in enemies) {
      explosions.add(Explosion(x: enemy.x, y: enemy.y, isLarge: true));
      score += enemy.points * 2;
    }
    enemies.clear();
    enemyBullets.clear();
    
    if (boss != null) {
      boss!.takeDamage(150);
      explosions.add(Explosion(x: boss!.x, y: boss!.y, isLarge: true));
      SoundManager.playSound('boss_hit');
    }
    
    for (int i = 0; i < 60; i++) {
      particles.add(particlePool.obtain(
        x: player.x,
        y: player.y,
        vx: random.nextDouble() * 25 - 12.5,
        vy: random.nextDouble() * 25 - 12.5,
        color: Colors.yellow,
        life: 80,
      ));
    }
  }

  void nextLevel() {
    if (currentLevel < bosses.length) {
      setState(() {
        levelTransition = true;
        currentLevel++;
        bossSpawned = false;
        bossMode = false;
        bossPhase = 0;
        boss = null;
        enemies.clear();
        enemyBullets.clear();
        playerHealth = 100;
        bossHealth = bosses[currentLevel - 1].health;
      });
      
      SoundManager.playSound('level_complete');
      SoundManager.playBGM('level_$currentLevel');
      initializeBackground();
      
      // 关卡过渡效果
      for (int i = 0; i < 30; i++) {
        transitionEffects.add(LevelTransitionEffect(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 800,
          color: _getLevelColor(),
        ));
      }
      
      GameData.unlockedLevel = currentLevel;
      GameData.saveData();
      
      Timer(Duration(seconds: 3), () {
        setState(() {
          levelTransition = false;
          transitionEffects.clear();
        });
      });
    } else {
      // 游戏通关
      gameWin();
    }
  }

  void gameWin() {
    setState(() {
      gameOver = true;
    });
    GameData.unlockAchievement('final_boss');
    if (score > 5000) GameData.unlockAchievement('score_5000');
    if (weaponLevel >= 5) GameData.unlockAchievement('weapon_master');
    SoundManager.playSound('level_complete');
  }

  void updateGame() {
    if (!gameStarted || gameOver || levelTransition) return;
    
    setState(() {
      player.update();
      
      // 更新关卡过渡效果
      transitionEffects.removeWhere((effect) {
        effect.update();
        return effect.isDead;
      });
      
      bullets.removeWhere((bullet) {
        bullet.update();
        return bullet.y < 0;
      });
      
      enemyBullets.removeWhere((bullet) {
        bullet.update(timeSlowActive ? 0.3 : 1.0);
        return bullet.y > 800;
      });
      
      enemies.removeWhere((enemy) {
        enemy.update(timeSlowActive ? 0.3 : 1.0);
        if (enemy.canShoot && random.nextDouble() < (timeSlowActive ? 0.005 : 0.02)) {
          enemyBullets.add(EnemyBullet(x: enemy.x, y: enemy.y + 30));
        }
        return enemy.y > 800;
      });
      
      // 更新Boss - 根据不同关卡有不同行为
      if (boss != null) {
        boss!.update(timeSlowActive ? 0.3 : 1.0);
        updateBossAI();
      }
      
      // 更新背景
      for (var planet in planets) {
        planet.update();
        if (planet.y > 900) {
          planet.y = -planet.radius;
          planet.x = random.nextDouble() * 500;
        }
      }
      
      for (var d in debris) {
        d.update();
        if (d.y > 820) {
          d.y = -10;
          d.x = random.nextDouble() * 400;
        }
      }
      
      for (var nebula in nebulas) {
        nebula.update();
        if (nebula.y > 950) {
          nebula.y = -nebula.size;
          nebula.x = random.nextDouble() * 500;
        }
      }
      
      explosions.removeWhere((explosion) {
        explosion.update();
        return explosion.isDead;
      });
      
      particles.removeWhere((particle) {
        particle.update();
        if (particle.isDead) {
          particlePool.release(particle);
          return true;
        }
        return false;
      });
      
      powerUps.removeWhere((powerUp) {
        powerUp.update();
        return powerUp.y > 800;
      });
      
      checkCollisions();
      
      if (playerHealth <= 0) {
        gameOver = true;
        _gameController.stop();
        _gameTimer.cancel();
        _shootTimer.cancel();
        
        // 保存最高分
        if (score > GameData.maxScore) {
          GameData.maxScore = score;
          GameData.saveData();
        }
      }
      
      // 检查Boss击败
      if (boss != null && boss!.health <= 0) {
        defeatBoss();
      }
    });
  }

  void updateBossAI() {
    if (boss == null) return;

    if (bossPhase == 0 && boss!.health < bossHealth * 0.6) bossPhase = 1;
    if (bossPhase == 1 && boss!.health < bossHealth * 0.3) bossPhase = 2;

    double attackChance = timeSlowActive ? 0.02 : 0.08;
    if (bossPhase == 1) attackChance *= 1.3;
    if (bossPhase == 2) attackChance *= 1.6;
    
    switch (currentLevel) {
      case 1: // 吾尔克西江 - 闪电攻击
        if (random.nextDouble() < attackChance) {
          // 三连发
          enemyBullets.add(EnemyBullet(x: boss!.x - 25, y: boss!.y + 60));
          enemyBullets.add(EnemyBullet(x: boss!.x, y: boss!.y + 60));
          enemyBullets.add(EnemyBullet(x: boss!.x + 25, y: boss!.y + 60));
        }
        if (random.nextDouble() < 0.03) {
          // 闪电链
          for (int i = 0; i < 5; i++) {
            enemyBullets.add(EnemyBullet(
              x: boss!.x + (i - 2) * 20,
              y: boss!.y + 60,
            ));
          }
        }
        if (bossPhase >= 1 && random.nextDouble() < 0.05) {
          for (int i = 0; i < 8; i++) {
            enemyBullets.add(EnemyBullet(
              x: random.nextDouble() * 400,
              y: boss!.y + 80,
            ));
          }
        }
        break;
        
      case 2: // 木斯塔帕江 - 烈火攻击
        if (random.nextDouble() < attackChance) {
          // 火焰扇形攻击
          for (int i = 0; i < 7; i++) {
            enemyBullets.add(EnemyBullet(
              x: boss!.x + (i - 3) * 15,
              y: boss!.y + 60,
            ));
          }
        }
        if (boss!.health < bosses[1].health * 0.5 && random.nextDouble() < 0.02) {
          // 火焰风暴（血量低于50%时）
          for (int i = 0; i < 10; i++) {
            enemyBullets.add(EnemyBullet(
              x: random.nextDouble() * 400,
              y: boss!.y + 80,
            ));
          }
        }
        if (bossPhase >= 2 && random.nextDouble() < 0.03) {
          for (int i = 0; i < 12; i++) {
            enemyBullets.add(EnemyBullet(
              x: i * 30.0,
              y: boss!.y + 100,
            ));
          }
        }
        break;
        
      case 3: // 司马义江 - 终极攻击
        if (random.nextDouble() < attackChance * 1.5) {
          // 导弹雨
          for (int i = 0; i < 5; i++) {
            enemyBullets.add(EnemyBullet(
              x: boss!.x + (i - 2) * 30,
              y: boss!.y + 60,
            ));
          }
        }
        if (boss!.health < bosses[2].health * 0.3 && random.nextDouble() < 0.015) {
          // 终极技：全屏弹幕
          for (int i = 0; i < 15; i++) {
            enemyBullets.add(EnemyBullet(
              x: i * 30.0,
              y: boss!.y + 100,
            ));
          }
        }
        if (bossPhase >= 2 && random.nextDouble() < 0.05) {
          for (int i = 0; i < 20; i++) {
            enemyBullets.add(EnemyBullet(
              x: random.nextDouble() * 400,
              y: boss!.y + 80,
            ));
          }
        }
        break;
    }
  }

  void defeatBoss() {
    SoundManager.playSound('boss_death');
    triggerScreenShake(35);
    
    explosions.add(Explosion(x: boss!.x, y: boss!.y, isLarge: true));
    
    for (int i = 0; i < 40; i++) {
      particles.add(particlePool.obtain(
        x: boss!.x + random.nextDouble() * 100 - 50,
        y: boss!.y + random.nextDouble() * 80 - 40,
        vx: random.nextDouble() * 15 - 7.5,
        vy: random.nextDouble() * 15 - 7.5,
        color: bosses[currentLevel - 1].color,
        life: 60,
      ));
    }
    
    score += 3000 * currentLevel;
    GameData.totalKills++;
    GameData.bossesDefeated++;
    
    // 解锁成就
    switch (currentLevel) {
      case 1:
        GameData.unlockAchievement('first_boss');
        break;
      case 2:
        GameData.unlockAchievement('second_boss');
        break;
      case 3:
        GameData.unlockAchievement('final_boss');
        break;
    }
    
    if (score > 1000) GameData.unlockAchievement('score_1000');
    
    boss = null;
    
    Timer(Duration(seconds: 2), () {
      nextLevel();
    });
  }

  void updateStars() {
    setState(() {
      for (var star in stars) {
        star.update();
        if (star.y > 800) {
          star.y = 0;
          star.x = random.nextDouble() * 400;
        }
      }
    });
  }

  void spawnEnemies() {
    if (bossMode || levelTransition) return;
    
    double spawnRate = 0.04 + (currentLevel - 1) * 0.01;
    if (random.nextDouble() < spawnRate) {
      enemies.add(Enemy(
        x: random.nextDouble() * 350,
        y: -50,
        type: random.nextInt(3),
        level: currentLevel,
      ));
    }
    
    if (random.nextDouble() < 0.025) {
      int powerType = random.nextInt(4);
      powerUps.add(PowerUp(
        x: random.nextDouble() * 350,
        y: -30,
        type: powerType,
      ));
    }
  }

  void checkBossSpawn() {
    int requiredScore = 200 + (currentLevel - 1) * 100;
    if (!bossSpawned && score > requiredScore) {
      setState(() {
        bossMode = true;
        bossSpawned = true;
        enemies.clear();
        boss = Boss(
          x: 150,
          y: 50,
          data: bosses[currentLevel - 1],
        );
      });
      SoundManager.playBGM('boss_${currentLevel}');
    }
  }

  void checkCollisions() {
    // 玩家子弹vs敌人
    for (int i = bullets.length - 1; i >= 0; i--) {
      for (int j = enemies.length - 1; j >= 0; j--) {
        if (bullets[i].collidesWith(enemies[j])) {
          SoundManager.playSound('explosion');
          triggerScreenShake(10);
          explosions.add(Explosion(x: enemies[j].x, y: enemies[j].y));
          for (int k = 0; k < 10; k++) {
            particles.add(particlePool.obtain(
              x: enemies[j].x,
              y: enemies[j].y,
              vx: random.nextDouble() * 10 - 5,
              vy: random.nextDouble() * 10 - 5,
              color: Colors.yellow,
              life: 30,
            ));
          }
          comboCount++;
          comboTimer = 90;
          int points = (enemies[j].points * (1 + comboCount * 0.1)).round();
          score += points;
          weaponUpgradePoints++;
          if (weaponUpgradePoints >= 8 && weaponLevel < 5) {
            weaponLevel++;
            weaponUpgradePoints = 0;
            HapticFeedback.lightImpact();
          }
          bullets.removeAt(i);
          enemies.removeAt(j);
          break;
        }
      }
    }
    
    // 玩家子弹vs Boss
    if (boss != null) {
      for (int i = bullets.length - 1; i >= 0; i--) {
        if (bullets[i].collidesWithBoss(boss!)) {
          int damage = 10;
          if (bullets[i].type == 2) damage = 20;
          if (bullets[i].type == 3) damage = 30;
          if (random.nextDouble() < 0.1) {
            damage *= 2;
          }

          boss!.takeDamage(damage);
          SoundManager.playSound('boss_hit');
          triggerScreenShake(8);
          explosions.add(Explosion(x: bullets[i].x, y: bullets[i].y));
          for (int k = 0; k < 6; k++) {
            particles.add(particlePool.obtain(
              x: bullets[i].x,
              y: bullets[i].y,
              vx: random.nextDouble() * 8 - 4,
              vy: random.nextDouble() * 8 - 4,
              color: Colors.red,
              life: 25,
            ));
          }
          comboCount++;
          comboTimer = 90;
          bullets.removeAt(i);
          break;
        }
      }
    }
    
    // 敌人子弹vs玩家
    if (!invincibleActive) {
      for (int i = enemyBullets.length - 1; i >= 0; i--) {
        if (enemyBullets[i].collidesWithPlayer(player)) {
          int damage = shieldActive ? 5 : 10;
          playerHealth -= damage;
          triggerScreenShake(18);
          explosions.add(Explosion(x: player.x, y: player.y));
          enemyBullets.removeAt(i);
          break;
        }
      }
    }
    
    // 玩家vs道具
    for (int i = powerUps.length - 1; i >= 0; i--) {
      if (powerUps[i].collidesWithPlayer(player)) {
        SoundManager.playSound('power_up');
        HapticFeedback.lightImpact();
        switch (powerUps[i].type) {
          case 0:
            playerHealth = (playerHealth + 30).clamp(0, 100);
            break;
          case 1:
            score += 150;
            break;
          case 2:
            weaponUpgradePoints += 4;
            break;
          case 3:
            timeSlowCooldown = 0;
            invincibleCooldown = 0;
            megaBlastCooldown = 0;
            break;
        }
        for (int k = 0; k < 12; k++) {
          particles.add(particlePool.obtain(
            x: powerUps[i].x,
            y: powerUps[i].y,
            vx: random.nextDouble() * 10 - 5,
            vy: random.nextDouble() * 10 - 5,
            color: Colors.green,
            life: 35,
          ));
        }
        powerUps.removeAt(i);
        break;
      }
    }
  }

  void movePlayer(Offset delta) {
    if (gameStarted && !gameOver && !levelTransition) {
      setState(() {
        player.x = (player.x + delta.dx * 1.8).clamp(25, 375);
        player.y = (player.y + delta.dy * 1.8).clamp(100, 750);
      });
    }
  }

  @override
  void dispose() {
    _gameController.dispose();
    _starController.dispose();
    _shakeController.dispose();
    _3dController.dispose();
    if (_gameTimer.isActive) _gameTimer.cancel();
    if (_shootTimer.isActive) _shootTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(perspectiveY * 0.01)
          ..rotateY(perspectiveX * 0.01)
          ..translate(shakeOffsetX + cameraShake, shakeOffsetY, 0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _getBackgroundColors(),
            ),
          ),
          child: Stack(
            children: [
              CustomPaint(
                painter: BackgroundPainter(stars, planets, debris, nebulas),
                size: Size.infinite,
              ),
              
              if (!gameStarted) _buildStartScreen(),
              if (gameStarted && !gameOver) _buildGameArea(),
              if (gameOver) _buildGameOverScreen(),
              if (levelTransition) _buildLevelTransition(),
              
              if (gameStarted && !gameOver && !levelTransition) _buildUI(),
              if (gameStarted && !gameOver && !levelTransition) _buildSkillButtons(),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getBackgroundColors() {
    switch (currentLevel) {
      case 1: return [Color(0xFF0A0E27), Color(0xFF16213E), Color(0xFF1E3A5F)];
      case 2: return [Color(0xFF2D1B0A), Color(0xFF4A1810), Color(0xFF5F1E1E)];
      case 3: return [Color(0xFF1A0A2D), Color(0xFF2D1810), Color(0xFF4A165F)];
      default: return [Color(0xFF0A0E27), Color(0xFF16213E), Color(0xFF0F3460)];
    }
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.cyan.withOpacity(0.4), Colors.blue.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.cyan.withOpacity(0.3), blurRadius: 25),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '🌌 银河战争：三大Boss挑战 🌌',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..shader = LinearGradient(
                        colors: [Colors.cyan, Colors.blue, Colors.purple],
                      ).createShader(Rect.fromLTWH(0.0, 0.0, 350.0, 70.0)),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ...bosses.asMap().entries.map((entry) {
                  int index = entry.key;
                  BossData boss = entry.value;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${index + 1}. ${boss.name} - ${boss.title}',
                      style: TextStyle(
                        color: boss.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 15),
                Text('🎵 动态音效系统', style: TextStyle(color: Colors.yellow, fontSize: 14)),
                Text('💾 数据持久化存档', style: TextStyle(color: Colors.orange, fontSize: 14)),
                Text('🎭 3D透视变换效果', style: TextStyle(color: Colors.purple, fontSize: 14)),
                Text('🏆 成就系统解锁', style: TextStyle(color: Colors.green, fontSize: 14)),
                SizedBox(height: 10),
                Text('最高分: ${GameData.maxScore}', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.cyan, Colors.blue]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: Colors.cyan.withOpacity(0.6), blurRadius: 20, spreadRadius: 3),
              ],
            ),
            child: ElevatedButton(
              onPressed: startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('🚀 开始征战', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTransition() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.8),
      child: CustomPaint(
        painter: TransitionPainter(transitionEffects),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '第 $currentLevel 关',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: _getLevelColor(),
                  shadows: [
                    Shadow(color: _getLevelColor(), blurRadius: 20),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Boss: ${bosses[currentLevel - 1].name}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                bosses[currentLevel - 1].title,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_getLevelColor()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return GestureDetector(
      onPanUpdate: (details) => movePlayer(details.delta),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: GamePainter(
            player: player,
            enemies: enemies,
            bullets: bullets,
            enemyBullets: enemyBullets,
            explosions: explosions,
            powerUps: powerUps,
            particles: particles,
            boss: boss,
            timeSlowActive: timeSlowActive,
            invincibleActive: invincibleActive,
            currentLevel: currentLevel,
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    bool isWin = currentLevel > bosses.length;
    return Center(
      child: Container(
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isWin 
              ? [Colors.green.withOpacity(0.4), Colors.cyan.withOpacity(0.4)]
              : [Colors.red.withOpacity(0.4), Colors.purple.withOpacity(0.4)],
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWin ? '🎉 恭喜通关！ 🎉' : '💀 游戏结束 💀',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: isWin ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 20),
            Text('🏆 最终得分: $score', style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('⭐ 达到关卡: $currentLevel/${bosses.length}', style: TextStyle(fontSize: 20, color: Colors.white70)),
            Text('⚔️ 武器等级: ${weaponNames[weaponLevel]}', style: TextStyle(fontSize: 18, color: Colors.yellow)),
            if (score > GameData.maxScore) 
              Text('🥇 新纪录！', style: TextStyle(fontSize: 20, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            Text('🏆 解锁成就:', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ...GameData.achievements.entries.where((e) => e.value).map((e) => 
              Text('✅ ${e.key}', style: TextStyle(fontSize: 14, color: Colors.green))
            ).toList(),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: Text('🔄 再次挑战', style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.grey.withOpacity(0.5)]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _getLevelColor().withOpacity(0.5), width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🎯 $score', style: TextStyle(color: Colors.cyan, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('🌟 第${currentLevel}关', style: TextStyle(color: _getLevelColor(), fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('⚔️ ${weaponNames[weaponLevel]}', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (comboCount > 1)
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('🔥 连击 x$comboCount', style: TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Text('❤️ ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: Colors.red[900]),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: playerHealth / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                gradient: LinearGradient(colors: [Colors.green, Colors.lightGreen]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(' $playerHealth', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text('🔧 ', style: TextStyle(color: Colors.orange)),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.grey[800]),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: weaponUpgradePoints / 8,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                gradient: LinearGradient(colors: [Colors.orange, Colors.yellow]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(' $weaponUpgradePoints/8', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                  if (boss != null) ...[
                    SizedBox(height: 12),
                    Text('👑 Boss: ${boss!.data.name}', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(boss!.data.title, style: TextStyle(color: Colors.red[300], fontSize: 12)),
                    SizedBox(height: 5),
                    Container(
                      height: 12,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.grey[800]),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: boss!.health / boss!.data.health,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(colors: [boss!.data.color, boss!.data.color.withOpacity(0.7)]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillButtons() {
    return Positioned(
      bottom: 60,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSkillButton('⏰', '时间减慢', timeSlowCooldown <= 0, () => useSkill(0)),
          _buildSkillButton('🛡️', '无敌冲刺', invincibleCooldown <= 0, () => useSkill(1)),
          _buildSkillButton('💥', '清屏大招', megaBlastCooldown <= 0, () => useSkill(2)),
          _buildSkillButton('🔰', '能量护盾', shieldCooldown <= 0, () => useSkill(3)),
        ],
      ),
    );
  }

  Widget _buildSkillButton(String icon, String name, bool ready, VoidCallback onPressed) {
    return Column(
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ready 
              ? LinearGradient(colors: [_getLevelColor(), _getLevelColor().withOpacity(0.7)])
              : LinearGradient(colors: [Colors.grey, Colors.grey[700]!]),
            boxShadow: ready ? [
              BoxShadow(color: _getLevelColor().withOpacity(0.6), blurRadius: 15, spreadRadius: 3)
            ] : null,
          ),
          child: ElevatedButton(
            onPressed: ready ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: CircleBorder(),
            ),
            child: Text(icon, style: TextStyle(fontSize: 26)),
          ),
        ),
        SizedBox(height: 6),
        Text(name, style: TextStyle(color: ready ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// 数据类
class BossData {
  final String name;
  final String title;
  final Color color;
  final int health;
  final int level;
  
  BossData(this.name, this.title, this.color, this.health, this.level);
}

// 游戏对象类（升级版）
class Player {
  double x = 200;
  double y = 600;
  double engineFlame = 0;
  
  void update() {
    engineFlame += 0.4;
  }
}

class Enemy {
  double x, y;
  int type;
  bool canShoot;
  int points;
  double rotation = 0;
  int level;
  
  Enemy({required this.x, required this.y, required this.type, required this.level})
      : canShoot = type > 0,
        points = (type + 1) * 25 * level;
  
  void update(double timeScale) {
    y += (2.5 + type * 0.7 + level * 0.3) * timeScale;
    rotation += 0.12 * timeScale;
  }
}

class Boss {
  double x, y;
  int health;
  BossData data;
  double direction = 1;
  double pulse = 0;
  
  Boss({required this.x, required this.y, required this.data}) : health = data.health;
  
  void update(double timeScale) {
    x += direction * (1.5 + data.level * 0.3) * timeScale;
    if (x <= 50 || x >= 250) direction *= -1;
    pulse += 0.18 * timeScale;
  }
  
  void takeDamage(int damage) {
    health -= damage;
  }
}

class Bullet {
  double x, y;
  int type; // 0: 普通, 1: 散弹, 2: 激光, 3: 等离子
  double angle;
  
  Bullet({required this.x, required this.y, this.type = 0, this.angle = 0});
  
  void update() {
    if (type == 1) {
      x += sin(angle) * 10;
      y -= cos(angle) * 15;
    } else {
      double speed = type == 2 ? 25 : (type == 3 ? 30 : 15);
      y -= speed;
    }
  }
  
  bool collidesWith(Enemy enemy) {
    return (x - enemy.x).abs() < 22 && (y - enemy.y).abs() < 22;
  }
  
  bool collidesWithBoss(Boss boss) {
    return (x - boss.x).abs() < 45 && (y - boss.y).abs() < 45;
  }
}

class EnemyBullet {
  double x, y;
  
  EnemyBullet({required this.x, required this.y});
  
  void update(double timeScale) {
    y += 7 * timeScale;
  }
  
  bool collidesWithPlayer(Player player) {
    return (x - player.x).abs() < 28 && (y - player.y).abs() < 28;
  }
}

class Star {
  double x, y, speed, brightness, size, twinkle;
  Color color;
  
  Star({required this.x, required this.y, required this.speed, required this.brightness, required this.size, required this.twinkle, required this.color});
  
  void update() {
    y += speed;
    twinkle += 0.12;
  }
}

class Planet {
  double x, y, radius, speed;
  Color color;
  bool rings;
  double rotation = 0;
  
  Planet({required this.x, required this.y, required this.radius, required this.speed, required this.color, required this.rings});
  
  void update() {
    y += speed;
    rotation += 0.015;
  }
}

class SpaceDebris {
  double x, y, size, speed, rotation, rotationSpeed;
  
  SpaceDebris({required this.x, required this.y, required this.size, required this.speed, required this.rotation, required this.rotationSpeed});
  
  void update() {
    y += speed;
    rotation += rotationSpeed;
  }
}

class Nebula {
  double x, y, size, speed;
  Color color;
  double pulse;
  
  Nebula({required this.x, required this.y, required this.size, required this.speed, required this.color, required this.pulse});
  
  void update() {
    y += speed;
    pulse += 0.025;
  }
}

class Explosion {
  double x, y;
  int frame = 0;
  bool isDead = false;
  bool isLarge;
  
  Explosion({required this.x, required this.y, this.isLarge = false});
  
  void update() {
    frame++;
    if (frame > (isLarge ? 35 : 18)) isDead = true;
  }
}

class PowerUp {
  double x, y;
  int type;
  double rotation = 0;
  
  PowerUp({required this.x, required this.y, required this.type});
  
  void update() {
    y += 3.5;
    rotation += 0.18;
  }
  
  bool collidesWithPlayer(Player player) {
    return (x - player.x).abs() < 28 && (y - player.y).abs() < 28;
  }
}

class Particle {
  double x, y, vx, vy;
  Color color;
  int life, maxLife;
  bool isDead = false;
  
  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.life}) : maxLife = life;
  
  void update() {
    x += vx;
    y += vy;
    vy += 0.12;
    life--;
    if (life <= 0) isDead = true;
  }
}

class ParticlePool {
  final List<Particle> _pool = [];

  Particle obtain({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required Color color,
    required int life,
  }) {
    if (_pool.isNotEmpty) {
      final p = _pool.removeLast();
      p
        ..x = x
        ..y = y
        ..vx = vx
        ..vy = vy
        ..color = color
        ..life = life
        ..maxLife = life
        ..isDead = false;
      return p;
    }
    return Particle(x: x, y: y, vx: vx, vy: vy, color: color, life: life);
  }

  void release(Particle p) {
    _pool.add(p);
  }
}

class LevelTransitionEffect {
  double x, y;
  Color color;
  int life = 180;
  bool isDead = false;
  late double vx, vy;
  
  LevelTransitionEffect({required this.x, required this.y, required this.color}) {
    Random random = Random();
    vx = random.nextDouble() * 6 - 3;
    vy = random.nextDouble() * 6 - 3;
  }
  
  void update() {
    x += vx;
    y += vy;
    life--;
    if (life <= 0) isDead = true;
  }
}

// 绘制器类（终极版）
class BackgroundPainter extends CustomPainter {
  final List<Star> stars;
  final List<Planet> planets;
  final List<SpaceDebris> debris;
  final List<Nebula> nebulas;
  
  BackgroundPainter(this.stars, this.planets, this.debris, this.nebulas);
  
  @override
  void paint(Canvas canvas, Size size) {
    // 绘制星云
    for (var nebula in nebulas) {
      final paint = Paint()
        ..color = nebula.color.withOpacity(0.15 + sin(nebula.pulse) * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 35);
      canvas.drawCircle(Offset(nebula.x, nebula.y), nebula.size, paint);
    }
    
    // 绘制行星
    for (var planet in planets) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [planet.color, planet.color.withOpacity(0.4)],
        ).createShader(Rect.fromCircle(center: Offset(planet.x, planet.y), radius: planet.radius));
      
      canvas.drawCircle(Offset(planet.x, planet.y), planet.radius, paint);
      
      if (planet.rings) {
        final ringPaint = Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(Offset(planet.x, planet.y), planet.radius + 12, ringPaint);
        canvas.drawCircle(Offset(planet.x, planet.y), planet.radius + 18, ringPaint);
      }
    }
    
    // 绘制太空碎片
    for (var d in debris) {
      canvas.save();
      canvas.translate(d.x, d.y);
      canvas.rotate(d.rotation);
      
      final paint = Paint()..color = Colors.grey.withOpacity(0.8);
      canvas.drawRect(Rect.fromCenter(center: Offset(0, 0), width: d.size, height: d.size * 0.7), paint);
      
      canvas.restore();
    }
    
    // 绘制星星
    for (var star in stars) {
      final brightness = star.brightness * (0.6 + sin(star.twinkle) * 0.4);
      final paint = Paint()..color = star.color.withOpacity(brightness);
      canvas.drawCircle(Offset(star.x, star.y), star.size, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TransitionPainter extends CustomPainter {
  final List<LevelTransitionEffect> effects;
  
  TransitionPainter(this.effects);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var effect in effects) {
      final alpha = effect.life / 180.0;
      final paint = Paint()
        ..color = effect.color.withOpacity(alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(effect.x, effect.y), 15 * alpha, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GamePainter extends CustomPainter {
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<EnemyBullet> enemyBullets;
  final List<Explosion> explosions;
  final List<PowerUp> powerUps;
  final List<Particle> particles;
  final Boss? boss;
  final bool timeSlowActive;
  final bool invincibleActive;
  final int currentLevel;
  
  GamePainter({
    required this.player,
    required this.enemies,
    required this.bullets,
    required this.enemyBullets,
    required this.explosions,
    required this.powerUps,
    required this.particles,
    this.boss,
    required this.timeSlowActive,
    required this.invincibleActive,
    required this.currentLevel,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 时间减慢效果
    if (timeSlowActive) {
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
    
    // 绘制粒子效果
    for (var particle in particles) {
      _drawParticle(canvas, particle);
    }
    
    // 绘制玩家
    if (!invincibleActive || (DateTime.now().millisecondsSinceEpoch % 200) < 100) {
      _drawPlayer(canvas);
    }
    
    // 绘制敌人
    for (var enemy in enemies) {
      _drawEnemy(canvas, enemy);
    }
    
    // 绘制Boss
    if (boss != null) {
      _drawBoss(canvas, boss!);
    }
    
    // 绘制子弹
    for (var bullet in bullets) {
      _drawBullet(canvas, bullet);
    }
    
    // 绘制敌人子弹
    for (var bullet in enemyBullets) {
      _drawEnemyBullet(canvas, bullet);
    }
    
    // 绘制爆炸效果
    for (var explosion in explosions) {
      _drawExplosion(canvas, explosion);
    }
    
    // 绘制道具
    for (var powerUp in powerUps) {
      _drawPowerUp(canvas, powerUp);
    }
    
    // 无敌护盾效果
    if (invincibleActive) {
      final paint = Paint()
        ..color = _getLevelColor().withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(Offset(player.x, player.y), 40, paint);
    }
  }
  
  Color _getLevelColor() {
    switch (currentLevel) {
      case 1: return Colors.blue;
      case 2: return Colors.red;
      case 3: return Colors.purple;
      default: return Colors.cyan;
    }
  }
  
  void _drawPlayer(Canvas canvas) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.cyan, Colors.blue, Colors.purple],
      ).createShader(Rect.fromCircle(center: Offset(player.x, player.y), radius: 35));
    
    // 主体 - 更威猛的设计
    final path = Path();
    path.moveTo(player.x, player.y - 35);
    path.lineTo(player.x - 20, player.y + 20);
    path.lineTo(player.x - 12, player.y + 12);
    path.lineTo(player.x, player.y + 8);
    path.lineTo(player.x + 12, player.y + 12);
    path.lineTo(player.x + 20, player.y + 20);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // 侧翼增强
    final wingPaint = Paint()..color = Colors.cyan.withOpacity(0.9);
    canvas.drawCircle(Offset(player.x - 25, player.y), 10, wingPaint);
    canvas.drawCircle(Offset(player.x + 25, player.y), 10, wingPaint);
    
    // 引擎效果升级
    final enginePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.orange, Colors.red, Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(player.x, player.y + 30), radius: 18));
    
    canvas.drawCircle(Offset(player.x - 12, player.y + 30 + sin(player.engineFlame) * 6), 8, enginePaint);
    canvas.drawCircle(Offset(player.x + 12, player.y + 30 + sin(player.engineFlame + 1) * 6), 8, enginePaint);
    canvas.drawCircle(Offset(player.x, player.y + 35 + sin(player.engineFlame + 0.5) * 8), 7, enginePaint);
    
    // 驾驶舱
    final cockpitPaint = Paint()
      ..color = Colors.lightBlue
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(player.x, player.y - 10), 10, cockpitPaint);
  }
  
  void _drawEnemy(Canvas canvas, Enemy enemy) {
    final colors = [
      [Colors.red, Colors.orange],
      [Colors.purple, Colors.pink],
      [Colors.green, Colors.lightGreen]
    ];
    
    canvas.save();
    canvas.translate(enemy.x, enemy.y);
    canvas.rotate(enemy.rotation);
    
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors[enemy.type],
      ).createShader(Rect.fromCircle(center: Offset(0, 0), radius: 25));
    
    // 敌人设计升级
    final path = Path();
    path.moveTo(0, -22);
    path.lineTo(-18, 22);
    path.lineTo(-8, 15);
    path.lineTo(0, 10);
    path.lineTo(8, 15);
    path.lineTo(18, 22);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // 敌人武器系统
    if (enemy.canShoot) {
      final weaponPaint = Paint()..color = Colors.red;
      canvas.drawRect(Rect.fromCenter(center: Offset(-10, 12), width: 4, height: 10), weaponPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(10, 12), width: 4, height: 10), weaponPaint);
    }
    
    // 核心升级
    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(0, 0), 8, corePaint);
    
    canvas.restore();
  }
  
  void _drawBoss(Canvas canvas, Boss boss) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [boss.data.color, boss.data.color.withOpacity(0.7), Colors.white],
      ).createShader(Rect.fromCenter(center: Offset(boss.x, boss.y), width: 140, height: 120));
    
    // Boss主体设计
    final mainBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(boss.x, boss.y), width: 120, height: 100),
      Radius.circular(20),
    );
    canvas.drawRRect(mainBody, paint);
    
    // 多层装甲系统
    final armorPaint1 = Paint()..color = boss.data.color.withOpacity(0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(boss.x, boss.y), width: 100, height: 80),
        Radius.circular(15),
      ),
      armorPaint1,
    );
    
    final armorPaint2 = Paint()..color = boss.data.color.withOpacity(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(boss.x, boss.y), width: 80, height: 60),
        Radius.circular(10),
      ),
      armorPaint2,
    );
    
    // Boss专属脉冲效果
    for (int i = 0; i < 4; i++) {
      final pulsePaint = Paint()
        ..color = boss.data.color.withOpacity(0.15 + sin(boss.pulse + i) * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (5 - i).toDouble();
      canvas.drawCircle(Offset(boss.x, boss.y), 70 + sin(boss.pulse + i) * 10, pulsePaint);
    }
    
    // Boss武器系统升级
    final weaponPaint = Paint()..color = Colors.cyan;
    for (int i = 0; i < 5; i++) {
      canvas.drawRect(Rect.fromCenter(center: Offset(boss.x - 40 + i * 20, boss.y + 30), width: 8, height: 25), weaponPaint);
      canvas.drawRect(Rect.fromCenter(center: Offset(boss.x - 40 + i * 20, boss.y + 40), width: 10, height: 15), weaponPaint);
    }
    
    // Boss标识
    final textPainter = TextPainter(
      text: TextSpan(
        text: '👑 ${boss.data.name} 👑',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(boss.x - 50, boss.y - 80));
    
    final titlePainter = TextPainter(
      text: TextSpan(
        text: boss.data.title,
        style: TextStyle(
          color: boss.data.color,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(canvas, Offset(boss.x - 40, boss.y - 95));
  }
  
  void _drawBullet(Canvas canvas, Bullet bullet) {
    Paint paint;
    
    switch (bullet.type) {
      case 0: // 普通子弹
        paint = Paint()
          ..shader = LinearGradient(
            colors: [Colors.cyan, Colors.white],
          ).createShader(Rect.fromCircle(center: Offset(bullet.x, bullet.y), radius: 6));
        canvas.drawCircle(Offset(bullet.x, bullet.y), 5, paint);
        break;
      case 1: // 散弹
        paint = Paint()..color = Colors.orange;
        canvas.drawCircle(Offset(bullet.x, bullet.y), 4, paint);
        break;
      case 2: // 激光
        paint = Paint()
          ..shader = LinearGradient(
            colors: [Colors.purple, Colors.pink],
          ).createShader(Rect.fromLTWH(bullet.x - 4, bullet.y - 20, 8, 40));
        canvas.drawRect(Rect.fromCenter(center: Offset(bullet.x, bullet.y), width: 8, height: 40), paint);
        
        final glowPaint = Paint()
          ..color = Colors.purple.withOpacity(0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRect(Rect.fromCenter(center: Offset(bullet.x, bullet.y), width: 12, height: 40), glowPaint);
        break;
      case 3: // 等离子炮
        paint = Paint()
          ..shader = RadialGradient(
            colors: [Colors.yellow, Colors.orange, Colors.red],
          ).createShader(Rect.fromCircle(center: Offset(bullet.x, bullet.y), radius: 8));
        canvas.drawCircle(Offset(bullet.x, bullet.y), 7, paint);
        
        final plasmaPaint = Paint()
          ..color = Colors.yellow.withOpacity(0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(bullet.x, bullet.y), 12, plasmaPaint);
        break;
    }
    
    // 子弹尾迹
    final trailPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.7)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(bullet.x, bullet.y),
      Offset(bullet.x, bullet.y + 15),
      trailPaint,
    );
  }
  
  void _drawEnemyBullet(Canvas canvas, EnemyBullet bullet) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.red, Colors.orange, Colors.red],
      ).createShader(Rect.fromCircle(center: Offset(bullet.x, bullet.y), radius: 7));
    
    canvas.drawCircle(Offset(bullet.x, bullet.y), 6, paint);
    
    final glowPaint = Paint()
      ..color = Colors.red.withOpacity(0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(bullet.x, bullet.y), 10, glowPaint);
  }
  
  void _drawExplosion(Canvas canvas, Explosion explosion) {
    final maxFrames = explosion.isLarge ? 35 : 18;
    final progress = explosion.frame / maxFrames;
    final alpha = 1.0 - progress;
    
    final colors = explosion.isLarge 
        ? [Colors.white, Colors.yellow, Colors.orange, Colors.red, Colors.purple]
        : [Colors.yellow, Colors.orange, Colors.red];
    
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i].withOpacity(alpha * (1 - i * 0.15))
        ..style = PaintingStyle.fill;
      
      final radius = (explosion.frame * (explosion.isLarge ? 5 : 4) + i * 8).toDouble();
      canvas.drawCircle(Offset(explosion.x, explosion.y), radius, paint);
    }
    
    // 爆炸闪光升级
    if (explosion.frame < 8) {
      final flashPaint = Paint()
        ..color = Colors.white.withOpacity(alpha * 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(explosion.x, explosion.y), explosion.frame * 12.0, flashPaint);
    }
  }
  
  void _drawPowerUp(Canvas canvas, PowerUp powerUp) {
    final colors = [
      [Colors.green, Colors.lightGreen],
      [Colors.blue, Colors.cyan],
      [Colors.orange, Colors.yellow],
      [Colors.purple, Colors.pink],
    ];
    
    final icons = ['❤️', '💎', '⚔️', '⚡'];
    
    canvas.save();
    canvas.translate(powerUp.x, powerUp.y);
    canvas.rotate(powerUp.rotation);
    
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors[powerUp.type],
      ).createShader(Rect.fromCircle(center: Offset(0, 0), radius: 20));
    
    // 主体发光升级
    final glowPaint = Paint()
      ..color = colors[powerUp.type][0].withOpacity(0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(0, 0), 25, glowPaint);
    
    canvas.drawCircle(Offset(0, 0), 18, paint);
    
    // 多层光环升级
    for (int i = 1; i <= 4; i++) {
      final ringPaint = Paint()
        ..color = colors[powerUp.type][0].withOpacity(0.4 / i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(0, 0), 18 + i * 6.0, ringPaint);
    }
    
    canvas.restore();
    
    // 道具图标
    final textPainter = TextPainter(
      text: TextSpan(
        text: icons[powerUp.type],
        style: TextStyle(fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(powerUp.x - 10, powerUp.y - 10));
  }
  
  void _drawParticle(Canvas canvas, Particle particle) {
    final alpha = particle.life / particle.maxLife;
    final paint = Paint()
      ..color = particle.color.withOpacity(alpha)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(particle.x, particle.y), 3 * alpha, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}