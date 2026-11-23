/// Worldwide Comprehensive Chess Openings Database (ECO Categorized)
class OpeningBookDatabase {
  /// Map of move sequences (UCI strings joined by space) to Opening Name
  static final Map<String, String> ecoBookMap = {
    // -------------------------------------------------------------------------
    // 0. OPENING SINGLE MOVES
    // -------------------------------------------------------------------------
    "e2e4": "King's Pawn Opening",
    "d2d4": "Queen's Pawn Opening",

    // -------------------------------------------------------------------------
    // 1. KING'S PAWN OPENINGS (1.e4 e5)
    // -------------------------------------------------------------------------
    // Ruy Lopez (Spanish Opening)
    "e2e4 e7e5 g1f3 b8c6 f1b5": "Ruy Lopez (Spanish Opening)",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6": "Ruy Lopez: Morphy Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4": "Ruy Lopez: Columbus Variation",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6": "Ruy Lopez: Main Line",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7": "Ruy Lopez: Closed Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 b3b3 d7d6 c2c3 e1g1 h2h3": "Ruy Lopez: Chigorin Variation",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 b3b3 d7d6 c2c3 e1g1 h2h3 c6b8": "Ruy Lopez: Breyer Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 b3b3 e8g8 c2c3 d7d5": "Ruy Lopez: Marshall Attack",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f6e4": "Ruy Lopez: Open Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5c6": "Ruy Lopez: Exchange Variation",
    "e2e4 e7e5 g1f3 b8c6 f1b5 g8f6": "Ruy Lopez: Berlin Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 f7f5": "Ruy Lopez: Schliemann Gambit",
    "e2e4 e7e5 g1f3 b8c6 f1b5 d7d6": "Ruy Lopez: Steinitz Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 g7g6": "Ruy Lopez: Smyslov Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 g8e7": "Ruy Lopez: Cozio Defense",
    "e2e4 e7e5 g1f3 b8c6 f1b5 f8c5": "Ruy Lopez: Classical Variation",
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 d7d6": "Ruy Lopez: Modern Steinitz",

    // Italian Game & Giuoco Piano
    "e2e4 e7e5 g1f3 b8c6 f1c4": "Italian Game",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5": "Giuoco Piano",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3": "Giuoco Piano: Main Line",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d4 e5d4 c3d4 c5b4 c1d2 b4d2 b1d2": "Giuoco Piano: Greco Variation",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4": "Evans Gambit",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4 c5b4 c2c3 b4a5": "Evans Gambit Accepted",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3": "Giuoco Pianissimo",
    "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6": "Two Knights Defense",
    "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5": "Two Knights Defense: Knight Attack",
    "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5 f6d5 g5f7": "Fried Liver Attack",
    "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5 b7b5": "Two Knights Defense: Ulvestad Variation",
    "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 d2d4 e5d4 e1g1 f8c5 e4e5": "Max Lange Attack",
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8e7": "Hungarian Defense",

    // Scotch Game & Scotch Gambit
    "e2e4 e7e5 g1f3 b8c6 d2d4": "Scotch Game",
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4": "Scotch Game: Main Line",
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 g8f6": "Scotch Game: Schmidt Variation",
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 f8c5": "Scotch Game: Classical Variation",
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f1c4": "Scotch Gambit",
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 c2c3": "Göring Gambit",

    // Petrov's Defense (Russian Game)
    "e2e4 e7e5 g1f3 g8f6": "Petrov's Defense",
    "e2e4 e7e5 g1f3 g8f6 f3e5": "Petrov's Defense: Classical Attack",
    "e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d7d5": "Petrov's Defense: Main Line",
    "e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f7": "Petrov: Cochrane Gambit",
    "e2e4 e7e5 g1f3 g8f6 d2d4": "Petrov's Defense: Steinitz Attack",

    // Four Knights Game & Three Knights
    "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6": "Four Knights Game",
    "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6 f1b5": "Four Knights Game: Spanish Variation",
    "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6 d2d4": "Four Knights Game: Scotch Variation",
    "e2e4 e7e5 g1f3 b8c6 b1c3": "Three Knights Game",

    // King's Gambit
    "e2e4 e7e5 f2f4": "King's Gambit",
    "e2e4 e7e5 f2f4 e5f4": "King's Gambit Accepted",
    "e2e4 e7e5 f2f4 e5f4 g1f3": "King's Gambit Accepted: Knight Option",
    "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5": "King's Gambit: Classical Defense",
    "e2e4 e7e5 f2f4 e5f4 f1c4": "King's Gambit Accepted: Bishop's Gambit",
    "e2e4 e7e5 f2f4 f8c5": "King's Gambit Declined: Classical",
    "e2e4 e7e5 f2f4 d7d5": "King's Gambit Declined: Falkbeer Countergambit",

    // Vienna Game & Bishop's Opening
    "e2e4 e7e5 b1c3": "Vienna Game",
    "e2e4 e7e5 b1c3 g8f6 f2f4": "Vienna Gambit",
    "e2e4 e7e5 b1c3 b8c6": "Vienna Game: Max Lange Defense",
    "e2e4 e7e5 f1c4": "Bishop's Opening",
    "e2e4 e7e5 f1c4 g8f6 d2d4": "Urusov Gambit",

    // Philidor Defense & Center Game
    "e2e4 e7e5 g1f3 d7d6": "Philidor Defense",
    "e2e4 e7e5 g1f3 d7d6 d2d4 e5d4 f3d4": "Philidor Defense: Exchange Variation",
    "e2e4 e7e5 d2d4 e5d4 d1d4": "Center Game",
    "e2e4 e7e5 d2d4 e5d4 c2c3": "Danish Gambit",

    // -------------------------------------------------------------------------
    // 2. SICILIAN DEFENSE (1.e4 c5)
    // -------------------------------------------------------------------------
    "e2e4 c7c5": "Sicilian Defense",
    "e2e4 c7c5 g1f3": "Sicilian Defense: Open Line Preparation",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3": "Sicilian Defense: Open Main Line",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6": "Sicilian Defense: Najdorf Variation",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1e3": "Sicilian Defense: Najdorf (English Attack)",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 f2f4": "Sicilian Defense: Najdorf (Amsterdam Variation)",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1g5": "Sicilian Defense: Najdorf (Main Line)",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 g7g6": "Sicilian Defense: Dragon Variation",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 g7g6 c1e3 f8g7 f2f3 e8g8 d1d2 b8c6": "Sicilian Defense: Dragon (Yugoslav Attack)",
    "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g7g6": "Sicilian Defense: Accelerated Dragon",
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 e7e6": "Sicilian Defense: Scheveningen Variation",
    "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 d7d6": "Sicilian Defense: Classical Variation",
    "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 e7e6": "Sicilian Defense: Taimanov Variation",
    "e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 a7a6": "Sicilian Defense: Kan Variation",
    "e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 b8c6": "Sicilian Defense: Four Knights Variation",
    "e2e4 c7c5 c2c3": "Sicilian Defense: Alapin Variation",
    "e2e4 c7c5 c2c3 d7d5 e4d5 d1d5 d2d4": "Sicilian Defense: Alapin Main Line",
    "e2e4 c7c5 b1c3": "Closed Sicilian",
    "e2e4 c7c5 b1c3 b8c6 g2g3": "Closed Sicilian: Traditional Line",
    "e2e4 c7c5 f2f4": "Sicilian Defense: Grand Prix Attack",
    "e2e4 c7c5 g1f3 b8c6 f1b5": "Sicilian Defense: Rossolimo Attack",
    "e2e4 c7c5 g1f3 d7d6 f1b5": "Sicilian Defense: Moscow Variation",
    "e2e4 c7c5 d2d4 c5d4 c2c3": "Sicilian Defense: Smith-Morra Gambit",
    "e2e4 c7c5 b2b4": "Sicilian Defense: Wing Gambit",

    // -------------------------------------------------------------------------
    // 3. FRENCH DEFENSE (1.e4 e6)
    // -------------------------------------------------------------------------
    "e2e4 e7e6": "French Defense",
    "e2e4 e7e6 d2d4 d7d5": "French Defense: Main Line",
    "e2e4 e7e6 d2d4 d7d5 e4e5": "French Defense: Advance Variation",
    "e2e4 e7e6 d2d4 d7d5 e4e5 c7c5 c2c3 b8c6 g1f3": "French Defense: Advance Main Line",
    "e2e4 e7e6 d2d4 d7d5 b1c3": "French Defense: Paulsen Variation",
    "e2e4 e7e6 d2d4 d7d5 b1c3 f1b4": "French Defense: Winawer Variation",
    "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6": "French Defense: Classical Variation",
    "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5": "French Defense: Classical (Burn/McCutcheon)",
    "e2e4 e7e6 d2d4 d7d5 b1d2": "French Defense: Tarrasch Variation",
    "e2e4 e7e6 d2d4 d7d5 b1d2 c7c5": "French Defense: Tarrasch (Open System)",
    "e2e4 e7e6 d2d4 d7d5 b1d2 g8f6": "French Defense: Tarrasch (Closed System)",
    "e2e4 e7e6 d2d4 d7d5 e4d5": "French Defense: Exchange Variation",
    "e2e4 e7e6 d2d4 d7d5 b1c3 d5e4 c3e4": "French Defense: Rubinstein Variation",
    "e2e4 e7e6 d2d3": "French Defense: King's Indian Attack",

    // -------------------------------------------------------------------------
    // 4. CARO-KANN DEFENSE (1.e4 c6)
    // -------------------------------------------------------------------------
    "e2e4 c7c6": "Caro-Kann Defense",
    "e2e4 c7c6 d2d4 d7d5": "Caro-Kann Defense: Main Line",
    "e2e4 c7c6 d2d4 d7d5 e4e5": "Caro-Kann Defense: Advance Variation",
    "e2e4 c7c6 d2d4 d7d5 e4e5 c8f5": "Caro-Kann Defense: Advance (Fischer-Tal)",
    "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4": "Caro-Kann Defense: Classical / Modern",
    "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5": "Caro-Kann Defense: Classical (Capablanca)",
    "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 b8d7": "Caro-Kann Defense: Steinitz Variation",
    "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 g8f6 e4f6 e7f6": "Caro-Kann Defense: Tartakower Variation",
    "e2e4 c7c6 d2d4 d7d5 e4d5 c6d5 c2c4": "Caro-Kann Defense: Panov-Botvinnik Attack",
    "e2e4 c7c6 d2d4 d7d5 e4d5 c6d5 c2c3": "Caro-Kann Defense: Exchange Variation",
    "e2e4 c7c6 d2d4 d7d5 f2f3": "Caro-Kann Defense: Fantasy Variation",
    "e2e4 c7c6 g1f3 d7d5 b1c3": "Caro-Kann Defense: Two Knights Line",

    // -------------------------------------------------------------------------
    // 5. OTHER SEMI-OPEN GAMES (Scandinavian, Alekhine, Pirc, Modern)
    // -------------------------------------------------------------------------
    "e2e4 d7d5": "Scandinavian Defense (Center Counter)",
    "e2e4 d7d5 e4d5 d1d5": "Scandinavian Defense: Main Line",
    "e2e4 d7d5 e4d5 d1d5 b1c3 d5a5 d2d4 c7c6 g1f3": "Scandinavian Defense: Classical Line",
    "e2e4 d7d5 e4d5 g8f6": "Scandinavian Defense: Modern Variation",
    "e2e4 g8f6": "Alekhine's Defense",
    "e2e4 g8f6 e4e5 f6d5 d2d4 d7d6 c2c4 d5b6 f2f4": "Alekhine's Defense: Four Pawns Attack",
    "e2e4 g8f6 e4e5 f6d5 d2d4 d7d6 c2c4 d5b6 e4d6": "Alekhine's Defense: Exchange Variation",
    "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6": "Pirc Defense",
    "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 f2f4": "Pirc Defense: Austrian Attack",
    "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 g1f3 f8g7": "Pirc Defense: Classical Line",
    "e2e4 g7g6 d2d4 f8g7": "Modern Defense",
    "e2e4 g7g6 d2d4 f8g7 b1c3 d7d6 c1e3": "Modern Defense: Standard Line",

    // -------------------------------------------------------------------------
    // 6. QUEEN'S PAWN & QUEEN'S GAMBIT (1.d4 d5)
    // -------------------------------------------------------------------------
    "d2d4 d7d5": "Queen's Pawn Game",
    "d2d4 d7d5 c2c4": "Queen's Gambit",
    "d2d4 d7d5 c2c4 d5c4": "Queen's Gambit Accepted",
    "d2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3": "Queen's Gambit Accepted: Main Line",
    "d2d4 d7d5 c2c4 e7e6": "Queen's Gambit Declined",
    "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6": "Queen's Gambit Declined: Traditional",
    "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3": "Queen's Gambit Declined: Orthodox Defense",
    "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 g1f3 c7c5": "Queen's Gambit Declined: Semi-Tarrasch",
    "d2d4 d7d5 c2c4 e7e6 b1c3 c7c5": "Queen's Gambit Declined: Tarrasch Defense",
    "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 b8d7": "Queen's Gambit Declined: Cambridge Springs",
    "d2d4 d7d5 c2c4 e7e6 c4d5": "Queen's Gambit Declined: Exchange Line",
    "d2d4 d7d5 c2c4 c7c6": "Slav Defense",
    "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4": "Slav Defense: Acceptance Line",
    "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 e7e6": "Semi-Slav Defense",
    "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 e7e6 e2e3 b8d7 d1c2": "Semi-Slav Defense: Meran Variation",
    "d2d4 d7d5 c2c4 e7e5": "Albin Countergambit",
    "d2d4 d7d5 c2c4 b8c6": "Chigorin Defense",
    "d2d4 d7d5 c1f4": "London System",
    "d2d4 d7d5 g1f3 g8f6 c1f4": "London System: Main Line",
    "d2d4 d7d5 g1f3 g8f6 e2e3 c7c5 c2c3": "Colle System",
    "d2d4 d7d5 b1c3 g8f6 c1g5": "Richter-Veresov Attack",
    "d2d4 d7d5 e2e4": "Blackmar-Diemer Gambit",

    // -------------------------------------------------------------------------
    // 7. INDIAN DEFENSES (1.d4 Nf6)
    // -------------------------------------------------------------------------
    "d2d4 g8f6": "Indian Defense",
    "d2d4 g8f6 c2c4 g7g6": "King's Indian / Grünfeld Prep",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7": "King's Indian Defense",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6": "King's Indian Defense: Main Line",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8 f1e2 e7e5": "King's Indian: Classical Variation",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 f2f3": "King's Indian: Samisch Variation",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 f2f4": "King's Indian: Four Pawns Attack",
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 c1g5": "King's Indian: Averbakh Variation",
    "d2d4 g8f6 c2c4 g7g6 b1c3 d7d5": "Grünfeld Defense",
    "d2d4 g8f6 c2c4 g7g6 b1c3 d7d5 c4d5 f6d5 e2e4 d5c3 b2c3 f8g7": "Grünfeld Defense: Exchange Variation",
    "d2d4 g8f6 c2c4 g7g6 b1c3 d7d5 g1f3 f8g7 d1b3": "Grünfeld Defense: Russian System",
    "d2d4 g8f6 c2c4 e7e6": "Queen's Indian / Nimzo-Indian Prep",
    "d2d4 g8f6 c2c4 e7e6 b1c3 f1b4": "Nimzo-Indian Defense",
    "d2d4 g8f6 c2c4 e7e6 b1c3 f1b4 e2e3": "Nimzo-Indian: Rubinstein Variation",
    "d2d4 g8f6 c2c4 e7e6 b1c3 f1b4 d1c2": "Nimzo-Indian: Classical (Capablanca)",
    "d2d4 g8f6 c2c4 e7e6 g1f3 b7b6": "Queen's Indian Defense",
    "d2d4 g8f6 c2c4 e7e6 g1f3 b7b6 g2g3 c8ba6": "Queen's Indian: Fianchetto Line",
    "d2d4 g8f6 c2c4 c7c5": "Benoni Defense",
    "d2d4 g8f6 c2c4 c7c5 d4d5 e7e6": "Modern Benoni",
    "d2d4 g8f6 c2c4 c7c5 d4d5 b7b5": "Benko Gambit (Volga Gambit)",
    "d2d4 g8f6 c2c4 c7c5 d4d5 b7b5 c4b5 a7a6": "Benko Gambit Accepted",
    "d2d4 f7f5": "Dutch Defense",
    "d2d4 f7f5 g2g3 g8f6 f1g2 g7g6 g1f3 f8g7 e1g1 e8g8 c2c4 d7d6": "Dutch Defense: Leningrad Variation",
    "d2d4 f7f5 e2e4": "Dutch Defense: Staunton Gambit",
    "d2d4 g8f6 c1g5": "Trompowsky Attack",
    "d2d4 g8f6 g1f3 e7e6 c1g5": "Torre Attack",
    "d2d4 d7d6 g1f3 c1g5": "Pereyra Attack",

    // -------------------------------------------------------------------------
    // 8. FLANK OPENINGS (English, Réti, Bird, Catalan, etc.)
    // -------------------------------------------------------------------------
    "c2c4": "English Opening",
    "c2c4 e7e5": "English Opening: King's English (Reverse Sicilian)",
    "c2c4 e7e5 b1c3 g8f6 g2g3": "English Opening: Bremen System",
    "c2c4 c7c5": "English Opening: Symmetrical Variation",
    "c2c4 g8f6 b1c3 d7d5": "English Opening: Anglo-Indian System",
    "g1f3": "Réti Opening",
    "g1f3 d7d5 c2c4": "Réti Opening: Main Line",
    "g1f3 d7d5 c2c4 d5d4": "Réti Opening: Advance System",
    "g1f3 d7d5 g2g3": "King's Indian Attack",
    "d2d4 d7d5 c2c4 e7e6 g1f3 g8f6 g2g3": "Catalan Opening",
    "d2d4 d7d5 c2c4 e7e6 g1f3 g8f6 g2g3 f8e7 f1g2 e8g8 e1g1": "Catalan Opening: Closed Main Line",
    "f2f4": "Bird's Opening",
    "f2f4 e7e5": "Bird's Opening: From's Gambit",
    "b2b3": "Nimzo-Larsen Attack",
    "b2b4": "Sokolsky / Polish / Orange Opening",
    "g2g4": "Grob's Attack",
    "b1c3": "Dunst Opening (Sleipner)",
    "d2d3": "Mieses Opening",
    "e2e3": "Van 't Kruijs Opening",
    "c2c3": "Saragossa Opening",
  };

  /// List of all move sequence UCI arrays for quick book checking
  static final List<List<String>> bookLines = ecoBookMap.keys
      .map((key) => key.split(' '))
      .toList();

  /// Looks up the exact opening name for a sequence of played UCI moves.
  static String? getOpeningName(List<String> playedUciHistory) {
    if (playedUciHistory.isEmpty) return null;

    String? bestMatchName;
    int maxLenMatched = 0;

    final playedKey = playedUciHistory.join(' ');

    ecoBookMap.forEach((sequence, name) {
      if (playedKey.startsWith(sequence) || sequence.startsWith(playedKey)) {
        final seqLen = sequence.split(' ').length;
        if (seqLen > maxLenMatched && playedUciHistory.length <= seqLen + 2) {
          maxLenMatched = seqLen;
          bestMatchName = name;
        }
      }
    });

    return bestMatchName;
  }
}
