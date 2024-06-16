const std = @import("std");

//The player actions are the players interactions with the sudoku that modifies it in any way
pub const PlayerActions = enum { SET, UNDO, CLEAR, REGENERATE, PSOLVE }; // The P in PSOLVE is left as an excersise for the reader

pub const Action = struct {
    playerAction: PlayerActions, //what type of action is this?

};

//All player-to-board interactions happen through the methods in this struct.
//This enables the action stack to record player actions and to potentially reverse them later.
//When a game is finished, the actionstack serves as a representation of the entire game
// allowing it to be replayed.
pub const ActionLayer = struct {

    //The action stack is a stack where all the players actions get pushed to.
    actionStack: std.ArrayList(usize),

    pub fn init(allocator: std.mem.Allocator) ActionLayer {
        return .{
            .actionStack = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *ActionLayer) void {
        self.actionStack.deinit();
    }
};
