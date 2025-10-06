// =====================================================
// SYSTÈME DE SANTÉ - JAVASCRIPT
// =====================================================

const HealthManager = {
    healthData: {
        health: 200,
        maxHealth: 200,
        armor: 0,
        maxArmor: 100,
        hunger: 100,
        thirst: 100,
        stress: 0
    },
    
    isDead: false,
    respawnTimer: null,

    init: function() {
        // Event listeners pour l'écran de mort
        const respawnBtn = document.getElementById('respawnButton');
        if (respawnBtn) {
            respawnBtn.addEventListener('click', () => this.requestRespawn());
        }
    },

    updateHealth: function(healthData) {
        this.healthData = healthData;
        
        // Afficher le HUD si caché
        const hud = document.getElementById('healthHUD');
        if (hud && hud.classList.contains('hidden')) {
            hud.classList.remove('hidden');
        }
        
        // Mettre à jour les barres
        this.updateBar('health', healthData.health, healthData.maxHealth);
        this.updateBar('armor', healthData.armor, healthData.maxArmor);
        this.updateBar('hunger', healthData.hunger, 100);
        this.updateBar('thirst', healthData.thirst, 100);
        this.updateBar('stress', healthData.stress, 100);
        
        // Ajouter des classes pour les valeurs basses
        this.checkLowValues();
    },

    updateBar: function(type, value, max) {
        const bar = document.getElementById(`${type}Bar`);
        const text = document.getElementById(`${type}Text`);
        
        if (!bar || !text) return;
        
        const percentage = Math.max(0, Math.min(100, (value / max) * 100));
        bar.style.width = percentage + '%';
        
        // Formater le texte
        if (type === 'hunger' || type === 'thirst' || type === 'stress') {
            text.textContent = Math.round(percentage) + '%';
        } else {
            text.textContent = Math.round(value);
        }
    },

    checkLowValues: function() {
        // Santé basse
        const healthBar = document.querySelector('.health-bar');
        if (this.healthData.health < 50) {
            healthBar.classList.add('low');
        } else {
            healthBar.classList.remove('low');
        }
        
        // Faim basse
        const hungerBar = document.querySelector('.hunger-bar');
        if (this.healthData.hunger < 20) {
            hungerBar.classList.add('low');
        } else {
            hungerBar.classList.remove('low');
        }
        
        // Soif basse
        const thirstBar = document.querySelector('.thirst-bar');
        if (this.healthData.thirst < 20) {
            thirstBar.classList.add('low');
        } else {
            thirstBar.classList.remove('low');
        }
    },

    updateMoney: function(moneyType, amount) {
        const elementId = moneyType === 'cash' ? 'cashAmount' : 'bankAmount';
        const element = document.getElementById(elementId);
        
        if (element) {
            // Animation du montant
            const currentAmount = parseInt(element.textContent.replace(/[$,]/g, '')) || 0;
            this.animateNumber(element, currentAmount, amount);
        }
    },

    animateNumber: function(element, start, end) {
        const duration = 1000; // 1 seconde
        const startTime = Date.now();
        
        const updateNumber = () => {
            const now = Date.now();
            const progress = Math.min((now - startTime) / duration, 1);
            
            const current = Math.floor(start + (end - start) * progress);
            element.textContent = '$' + current.toLocaleString();
            
            if (progress < 1) {
                requestAnimationFrame(updateNumber);
            }
        };
        
        updateNumber();
    },

    showDeathScreen: function(reason) {
        this.isDead = true;
        const deathScreen = document.getElementById('deathScreen');
        const deathReason = document.getElementById('deathReason');
        
        if (deathScreen) {
            deathScreen.classList.remove('hidden');
        }
        
        if (deathReason && reason) {
            deathReason.textContent = reason;
        }
        
        // Masquer le bouton de respawn initialement
        const respawnBtn = document.getElementById('respawnButton');
        if (respawnBtn) {
            respawnBtn.classList.add('hidden');
        }
    },

    hideDeathScreen: function() {
        this.isDead = false;
        const deathScreen = document.getElementById('deathScreen');
        
        if (deathScreen) {
            deathScreen.classList.add('hidden');
        }
        
        if (this.respawnTimer) {
            clearInterval(this.respawnTimer);
            this.respawnTimer = null;
        }
    },

    updateRespawnTimer: function(seconds) {
        const timerElement = document.getElementById('respawnTimer');
        
        if (timerElement) {
            const minutes = Math.floor(seconds / 60);
            const secs = seconds % 60;
            timerElement.textContent = `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        }
    },

    enableRespawn: function() {
        const respawnBtn = document.getElementById('respawnButton');
        const timerDiv = document.getElementById('deathTimer');
        
        if (respawnBtn) {
            respawnBtn.classList.remove('hidden');
        }
        
        if (timerDiv) {
            timerDiv.style.display = 'none';
        }
    },

    requestRespawn: function() {
        fetch(`https://${GetParentResourceName()}/requestRespawn`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }
};

// Initialisation
document.addEventListener('DOMContentLoaded', function() {
    HealthManager.init();
});

// Messages de FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'updateHealth':
            HealthManager.updateHealth(data.health);
            break;
            
        case 'updateMoney':
            HealthManager.updateMoney(data.moneyType, data.amount);
            break;
            
        case 'showDeathScreen':
            HealthManager.showDeathScreen(data.reason);
            break;
            
        case 'hideDeathScreen':
            HealthManager.hideDeathScreen();
            break;
            
        case 'updateRespawnTimer':
            HealthManager.updateRespawnTimer(data.time);
            break;
            
        case 'enableRespawn':
            HealthManager.enableRespawn();
            break;
    }
});

function GetParentResourceName() {
    if (window.location.hostname === 'nui-game-internal') {
        return window.location.pathname.replace(/^\/|\/$/g, '').split('/')[0];
    }
    return "crysis-core";
}