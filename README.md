# OP Card Scanner — One Piece TCG

> **⚡ Projet 100% Vibe Coded** — Entièrement généré et itéré avec GitHub Copilot (Claude Sonnet 4.6), sans une seule ligne de code écrite à la main. De l'architecture aux animations, chaque feature a été décrite en langage naturel et implémentée par l'IA en temps réel.

---

## C'est quoi ?

**OP Card Scanner** est une application mobile Flutter qui permet de **scanner une carte du jeu de cartes One Piece TCG** et d'obtenir instantanément ses informations : nom, édition, rareté et prix du marché.

Pointez votre caméra vers une carte, le scan se fait automatiquement, et vous avez en quelques secondes toutes les données de la carte affichées dans une interface soignée.

---

## Fonctionnalités

- **Auto-scan continu** — activez le mode auto et l'app détecte toute seule dès qu'une carte est dans le cadre, sans appuyer sur rien
- **Scan manuel** — bouton rouge pour capturer à la demande
- **Recadrage précis** — seul ce qui est dans le cadre est analysé, les autres cartes à l'écran sont ignorées
- **Reconnaissance OCR robuste** — Google ML Kit avec correction automatique des confusions O/0 fréquentes en OCR
- **Données en temps réel** — prix du marché (USD), prix minimum, rareté via l'API OPTCG
- **Gestion des variantes** — si une carte existe en plusieurs versions (alt art, parallel...), un sélecteur en grille apparaît avec les images
- **Lien Cardmarket** — accès direct à la fiche de la carte sur Cardmarket
- **Interface moderne** — laser animé sur le cadre de scan, badge de rareté, dégradés, animations fluides

---

## Stack technique

| Composant | Technologie |
|---|---|
| Framework | Flutter 3.x / Dart |
| OCR | Google ML Kit Text Recognition (Latin) |
| Caméra | `camera` package |
| Données cartes | [OPTCG API](https://optcgapi.com) |
| Recadrage image | `image` package (bakeOrientation + copyCrop) |
| Animations | `flutter_animate` |
| Cache images | `cached_network_image` |
| Stockage local | `shared_preferences` |
| Navigation externe | `url_launcher` |

---

## Format des cartes reconnu

L'OCR extrait les numéros de carte au format One Piece TCG :

```
OP01-001   →  booster set 1, carte 001
ST01-003   →  starter deck 1, carte 003
EB04-007   →  extra booster 4, carte 007
```

Le regex accepte les confusions O/0 de l'OCR et corrige automatiquement :
```
0P01-001  →  OP01-001  ✓
EB04-00O  →  EB04-000  ✓
```

---

## Lancer le projet

```bash
# Cloner le repo
git clone https://github.com/zdossantos/op-tcg-scanner.git
cd op_scanner_tcg

# Installer les dépendances
flutter pub get

# iOS — installer les pods
cd ios && pod install && cd ..

# Lancer sur un appareil connecté
flutter run
```

> **Prérequis iOS** : Xcode 15+, iOS 16.0 minimum (requis par google_mlkit_commons)

---

## Permissions requises

| Plateforme | Permission |
|---|---|
| iOS | `NSCameraUsageDescription` (Info.plist) |
| Android | `CAMERA` (AndroidManifest.xml) |

---

## À propos du Vibe Coding

Ce projet n'a pas été écrit "à la main". Chaque fonctionnalité a été demandée en français à GitHub Copilot :

- *"Intègre un système d'auto-scan qui scanne en continu et affiche si il détecte un truc"*
- *"Le scan scanne tout ce qu'il y a à l'écran, pas que ce qui est dans le cadre"*
- *"Fait moi un truc plus moderne avec le logo One Piece"*

L'IA a produit l'architecture, les services, les widgets, les animations, les corrections de bugs, et même ce README — le tout sans jamais écrire une ligne manuellement.

C'est une démonstration concrète de ce qu'on peut construire avec du **Vibe Coding** : une app mobile complète et fonctionnelle, en quelques heures de conversation.

---

## Disclaimer

Ce projet est un outil personnel non officiel. One Piece est une marque déposée de Toei Animation / Shueisha. Les données de cartes proviennent de l'API publique OPTCG.
