const Sudoku = @import("sudoku.zig");

pub const SolverType = enum { NAIVE, SIMD }; //These are placeholders until actual solvers are implemented


//Here goes the solvers

pub fn NaiveSolve(sudoku: anytype) bool {
    _ = sudoku; //What am i supposed to write when a parameter should be the container for a sudoku

    //Solving magic, modifying the original sudoku struct


    return true; //In the futuer, the solvers should return lists of player actions in order to replay them later
}