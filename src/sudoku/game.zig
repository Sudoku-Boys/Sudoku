const std = @import("std");
const Solver = @import("Solver.zig");
const Sudoku = @import("sudoku.zig");

pub const GameType = enum { EMPTY, CLASSIC };
pub const ActionEvent = enum { NONE, CLEAR_BOARD, SET_CELL, CLEAR_CELL, COMPLETE_SOLVE, HINT }; //The actions a player can take
pub const Action = struct {
    event: ActionEvent = .NONE,
    x: u16 = 0,
    y: u16 = 0,
    value: u16 = 0,
}; //Action objects

//The Game struct is meant to represent individual games of sudoku
//It takes input from the player in the form of actions sent by the main game manager (not yet implemented)
const Game = struct {
    solver: Solver.SolverType = .NAIVE,
    solved: bool = false,
    //sudoku: //not sure what type i should give the variable that holds the sudoku

    pub fn HandleAction(action: Action) void {
        //TODO: Save the action for a future replay

        switch (action.ActionEvent) {
            .NONE => {},
        }
    }

    //Runs the asociated solver until completion or failure.
    pub fn FullySolve(self: *Game) bool {
        var isSolved = false;
        switch (self.solver) {
            //.NAIVE => isSolved = Solver.NaiveSolve(sudoku),
        }

        if (isSolved) self.solved = false;
        return isSolved; //Solve successful
    }
};

//Creates the game based on the type wanted and the parameters
pub fn CreateGame(gameType: GameType) Game {
    _ = gameType;
}
