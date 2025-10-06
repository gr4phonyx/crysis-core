console.log("NUI JS chargé");

var characters = [];
var maxCharacters = 3;

// =====================================================
// SYSTÈME DE NOTIFICATIONS
// =====================================================

const NotificationManager = {
    queue: [],
    maxVisible: 5,
    currentNotifications: 0,

    show: function(message, type = 'info', duration = 5000) {
        const notification = {
            id: Date.now() + Math.random(),
            message: message,
            type: type,
            duration: duration
        };

        if (this.currentNotifications >= this.maxVisible) {
            this.queue.push(notification);
            return;
        }

        this.display(notification);
    },

    display: function(notification) {
        this.currentNotifications++;

        const container = document.getElementById('notifications');
        if (!container) {
            console.error('Container notifications introuvable');
            return;
        }

        const notifEl = document.createElement('div');
        notifEl.className = `notification ${notification.type}`;
        notifEl.id = `notif-${notification.id}`;
        notifEl.style.opacity = '0';
        notifEl.style.transform = 'translateX(400px)';

        const icon = this.getIcon(notification.type);
        
        notifEl.innerHTML = `
            <div class="notification-icon">${icon}</div>
            <div class="notification-content">
                <div class="notification-message">${this.escapeHtml(notification.message)}</div>
            </div>
            <button class="notification-close" onclick="NotificationManager.close('${notification.id}')">✕</button>
            <div class="notification-progress"></div>
        `;

        container.appendChild(notifEl);

        setTimeout(() => {
            notifEl.style.transition = 'all 0.3s ease-out';
            notifEl.style.opacity = '1';
            notifEl.style.transform = 'translateX(0)';
        }, 10);

        const progressBar = notifEl.querySelector('.notification-progress');
        if (progressBar && notification.duration > 0) {
            progressBar.style.transition = `width ${notification.duration}ms linear`;
            setTimeout(() => {
                progressBar.style.width = '0%';
            }, 50);
        }

        if (notification.duration > 0) {
            setTimeout(() => {
                this.close(notification.id);
            }, notification.duration);
        }
    },

    close: function(id) {
        const notifEl = document.getElementById(`notif-${id}`);
        if (!notifEl) return;

        notifEl.style.transition = 'all 0.3s ease-in';
        notifEl.style.opacity = '0';
        notifEl.style.transform = 'translateX(400px)';

        setTimeout(() => {
            notifEl.remove();
            this.currentNotifications--;

            if (this.queue.length > 0) {
                const next = this.queue.shift();
                this.display(next);
            }
        }, 300);
    },

    getIcon: function(type) {
        const icons = {
            'success': '✓',
            'error': '✕',
            'warning': '⚠',
            'info': 'ℹ'
        };
        return icons[type] || icons['info'];
    },

    escapeHtml: function(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    closeAll: function() {
        const container = document.getElementById('notifications');
        if (container) {
            container.innerHTML = '';
        }
        this.currentNotifications = 0;
        this.queue = [];
    }
};

window.NotificationManager = NotificationManager;

// =====================================================
// UN SEUL LISTENER POUR TOUS LES MESSAGES
// =====================================================

window.addEventListener('message', function(event) {
    var data = event.data;
    
    switch (data.action) {
        case 'openCharacterSelection':
            openCharacterSelection(data.characters, data.maxCharacters);
            break;
        case 'notify':
            // ⬅️ UN SEUL APPEL ICI
            NotificationManager.show(data.message, data.type || 'info', data.duration || 5000);
            break;
        case 'closeUI':
            closeCharacterSelection();
            break;
        case 'updateMoney':
            updateMoneyDisplay(data.moneyType, data.amount);
            break;
    }
});

// =====================================================
// GESTION DES PERSONNAGES
// =====================================================

function openCharacterSelection(chars, max) {
    characters = chars || [];
    maxCharacters = max || 3;

    var selectionDiv = document.getElementById('characterSelection');
    if (selectionDiv) selectionDiv.classList.remove('hidden');

    var characterCount = document.getElementById('characterCount');
    if (characterCount) characterCount.textContent = characters.length + "/" + maxCharacters + " personnages";

    var charactersList = document.getElementById('charactersList');
    if (charactersList) {
        charactersList.innerHTML = '';

        characters.forEach(function(char) {
            var card = document.createElement('div');
            card.className = 'character-card';

            var h3 = document.createElement('h3');
            h3.textContent = char.firstname + ' ' + char.lastname;

            var info = document.createElement('div');
            info.className = 'character-info';

            var p1 = document.createElement('p');
            p1.textContent = 'Date de naissance: ' + char.dateofbirth;

            var p2 = document.createElement('p');
            p2.textContent = 'Job: ' + (char.job || 'Sans emploi');

            var p3 = document.createElement('p');
            p3.textContent = 'Argent: $' + (char.cash || 0);

            info.appendChild(p1);
            info.appendChild(p2);
            info.appendChild(p3);

            var actions = document.createElement('div');
            actions.className = 'character-actions';

            var playBtn = document.createElement('button');
            playBtn.className = 'btn btn-success';
            playBtn.textContent = 'Jouer';
            playBtn.onclick = function() {
                selectCharacter(char.id);
            };

            var deleteBtn = document.createElement('button');
            deleteBtn.className = 'btn btn-danger';
            deleteBtn.textContent = 'Supprimer';
            deleteBtn.onclick = function() {
                deleteCharacter(char.id);
            };

            actions.appendChild(playBtn);
            actions.appendChild(deleteBtn);

            card.appendChild(h3);
            card.appendChild(info);
            card.appendChild(actions);

            charactersList.appendChild(card);
        });
    }

    // Gérer le bouton créer
    var createBtn = document.getElementById('createCharBtn');
    if (createBtn) {
        if (characters.length >= maxCharacters) {
            createBtn.disabled = true;
            createBtn.style.opacity = '0.5';
        } else {
            createBtn.disabled = false;
            createBtn.style.opacity = '1';
        }
    }
}

function closeCharacterSelection() {
    var selectionDiv = document.getElementById('characterSelection');
    if (selectionDiv) selectionDiv.classList.add('hidden');

    var charactersList = document.getElementById('charactersList');
    if (charactersList) charactersList.innerHTML = '';
}

function selectCharacter(charId) {
    console.log("Sélection personnage:", charId);
    fetch("https://" + GetParentResourceName() + "/selectCharacter", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({ characterId: parseInt(charId) })
    });

    closeCharacterSelection();
}

function deleteCharacter(charId) {
    if (confirm("Voulez-vous vraiment supprimer ce personnage ?")) {
        console.log("Suppression personnage:", charId);
        fetch("https://" + GetParentResourceName() + "/deleteCharacter", {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({ characterId: parseInt(charId) })
        });
    }
}

function updateMoneyDisplay(moneyType, amount) {
    const elementId = moneyType === 'cash' ? 'cashAmount' : 'bankAmount';
    const element = document.getElementById(elementId);
    if (element) {
        element.textContent = '$' + amount.toLocaleString();
    }
}

function GetParentResourceName() {
    if (window.location.hostname === 'nui-game-internal') {
        return window.location.pathname.replace(/^\/|\/$/g, '').split('/')[0];
    }
    return "crysis-core";
}

// =====================================================
// ÉVÉNEMENTS DOM
// =====================================================

document.addEventListener('DOMContentLoaded', function() {
    console.log("DOM prêt");

    // Bouton créer personnage
    var createBtn = document.getElementById('createCharBtn');
    if (createBtn) {
        createBtn.addEventListener('click', function() {
            console.log("Clic créer personnage");
            var modal = document.getElementById('createCharModal');
            if (modal) modal.classList.remove('hidden');
        });
    }

    // Bouton annuler création
    var cancelBtn = document.getElementById('cancelCreate');
    if (cancelBtn) {
        cancelBtn.addEventListener('click', function() {
            var modal = document.getElementById('createCharModal');
            if (modal) modal.classList.add('hidden');
        });
    }

    // Formulaire de création
    var form = document.getElementById('createCharForm');
    if (form) {
        form.addEventListener('submit', function(e) {
            e.preventDefault();
            console.log("Formulaire soumis");

            const firstname = document.getElementById('firstname').value.trim();
            const lastname = document.getElementById('lastname').value.trim();
            const dateofbirth = document.getElementById('dateofbirth').value;
            const sex = document.getElementById('sex').value;
            const height = parseInt(document.getElementById('height').value, 10);
            const nationality = document.getElementById('nationality').value;

            // Validation côté client
            const nameRegex = /^[a-zA-ZÀ-ÖØ-öø-ÿ\- ]+$/;

            if (!nameRegex.test(firstname) || !nameRegex.test(lastname)) {
                NotificationManager.show("Le prénom et le nom ne doivent contenir que des lettres.", 'error');
                return;
            }

            const birthDate = new Date(dateofbirth);
            const today = new Date();
            const age = today.getFullYear() - birthDate.getFullYear();
            if (age < 16 || age > 100) {
                NotificationManager.show("L'âge doit être compris entre 16 et 100 ans.", 'error');
                return;
            }

            if (height < 150 || height > 220) {
                NotificationManager.show("La taille doit être comprise entre 150 et 220 cm.", 'error');
                return;
            }

            const data = { firstname, lastname, dateofbirth, sex, height, nationality };
            console.log("Envoi données validées:", data);

            fetch("https://" + GetParentResourceName() + "/createCharacter", {
                method: "POST",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify(data)
            }).then(function() {
                console.log("Personnage envoyé");
                var modal = document.getElementById('createCharModal');
                if (modal) modal.classList.add('hidden');
                form.reset();
            }).catch(function(error) {
                console.error("Erreur création personnage:", error);
                NotificationManager.show("Erreur lors de la création du personnage", 'error');
            });
        });
    }

    // Fermer avec Échap
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            var modal = document.getElementById('createCharModal');
            if (modal && !modal.classList.contains('hidden')) {
                modal.classList.add('hidden');
            }
        }
    });
});

// =====================================================
// TESTS (à supprimer en production)
// =====================================================

// Test des notifications avec la touche T (uniquement en développement)
if (window.location.hostname !== 'nui-game-internal') {
    document.addEventListener('keydown', function(e) {
        if (e.key === 't') {
            NotificationManager.show('Test notification info', 'info');
        } else if (e.key === 's') {
            NotificationManager.show('Test notification succès', 'success');
        } else if (e.key === 'e') {
            NotificationManager.show('Test notification erreur', 'error');
        } else if (e.key === 'w') {
            NotificationManager.show('Test notification warning', 'warning');
        }
    });
}