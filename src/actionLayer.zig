const std = @import("std");
const Coordinate = @import("sudoku/Coordinate.zig");
const solve = @import("sudoku/solve.zig");

//The player actions are the players interactions with the sudoku that modifies it in any way
pub const PlayerActions = enum { SET, CLEAR, REGENERATE, PSOLVE }; // The P in PSOLVE is left as an excersise for the reader

pub const Action = struct {
    playerAction: PlayerActions, //what type of action is this?
    coord: Coordinate = Coordinate{ .i = 0, .j = 0 }, //Where on the board?
    value: usize = 0, //Any value connected to the action?
    oldValue: usize = 0, //Do we need to remember something later?
};

//All player-to-board interactions happen through the methods in this struct.
//This enables the action stack to record player actions and to potentially reverse them later.
//When a game is finished, the actionstack serves as a representation of the entire game
// allowing it to be replayed.
pub const ActionLayer = struct {
    actionStack: std.ArrayList(Action), //The action stack is where all the players actions get pushed to.
    redoStack: std.ArrayList(Action), //The redo stack is where undone actions are pushed to
    boardStack: std.ArrayList([]u8), //if a board asociated with an action should be kept, it goes here
    allocator: std.mem.Allocator,

    fn executeAction(self: *ActionLayer, sudoku: anytype, action: Action) !void {
        switch (action.playerAction) {
            .SET => {
                //We save the current value of the square to the action, before adding the action to the stack
                try self.actionStack.append(Action{
                    .playerAction = PlayerActions.SET,
                    .coord = action.coord,
                    .value = action.value,
                    .oldValue = sudoku.get(action.coord), //this remembers
                });

                sudoku.set(action.coord, @intCast(action.value));
            },
            .CLEAR => {
                //We save all the numbers of the current sudoku in an array and push it to the boardStack
                var numbers: []u8 = try self.allocator.alloc(u8, sudoku.board.len);
                for (0..sudoku.board.len) |i| {
                    numbers[i] = sudoku.board[i];
                }
                try self.boardStack.append(numbers);
                //self.allocator.free(numbers);

                //We remember to append the action to the actionStack
                try self.actionStack.append(Action{
                    .playerAction = PlayerActions.CLEAR,
                    .coord = action.coord,
                    .value = action.value,
                });

                sudoku.clear();
            },
            .PSOLVE => {
                //We save the board like with .CLEAR above
                var numbers: []u8 = try self.allocator.alloc(u8, sudoku.board.len);
                for (0..sudoku.board.len) |i| {
                    numbers[i] = sudoku.board[i];
                }
                try self.boardStack.append(numbers);

                try self.actionStack.append(Action{
                    .playerAction = PlayerActions.PSOLVE,
                    .coord = action.coord,
                    .value = action.value,
                });

                _ = try solve.solve(.MRV, sudoku, self.allocator);
            },
            .REGENERATE => {
                //We don't actually generate the new sudoku here, but clear the stacks
                self.redoStack.clearAndFree();
                for (self.boardStack.items) |value| {
                    self.allocator.free(value); //We remember to free the arrays stored in boardstack
                }
                self.boardStack.clearAndFree();
                self.actionStack.clearAndFree();
            },
        }
    }

    //This function is the publicly accessible version of executeAction, to differentiate redoing, and doing for the first time
    pub fn performAction(self: *ActionLayer, sudoku: anytype, action: Action) !void {
        //When we perform an action after undoing, then we shouln't be able to redo afterwards
        self.redoStack.clearAndFree();

        try self.executeAction(sudoku, action);
    }

    //We ask the actionlayer to recall the last action we did and undo it
    pub fn undoLast(self: *ActionLayer, sudoku: anytype) !void {
        if (self.actionStack.items.len > 0) {
            self.undoAction(sudoku, self.actionStack.getLast());
            try self.redoStack.append(self.actionStack.pop()); //Add the undone action to the redo stack so we can redo it later
        }
    }

    pub fn attemptRedo(self: *ActionLayer, sudoku: anytype) !void {
        if (self.redoStack.items.len > 0) {
            try self.executeAction(sudoku, self.redoStack.pop());
        }
    }

    //Uses the actions info and maybe the boardStack to reverse whatever action we just took
    fn undoAction(self: *ActionLayer, sudoku: anytype, action: Action) void {
        switch (action.playerAction) {
            .SET => {
                sudoku.set(action.coord, @intCast(action.oldValue));
            },
            .CLEAR, .PSOLVE => {
                const numbers: []u8 = self.boardStack.pop();
                for (0..sudoku.board.len) |i| {
                    sudoku.board[i] = @intCast(numbers[i]);
                }

                // Ensure internal state is consistent.
                sudoku.rebuild();
                self.allocator.free(numbers);
            },
            .REGENERATE => {
                //JK. No undoing that
            },
        }
    }

    //Places exactly N correct numbers on the current board, semi randomly
    //Makes a copy of the board, solves it, and randomly picks squares with different numbers than the original board
    fn solveN(self: *ActionLayer, sudoku: anytype, N: usize) void {
        _ = try solve.solve(.MRV, sudoku, self.allocator);
    }

    //Places exactly 1 correct number on the current board, semi randomly
    pub fn solveOne(self: *ActionLayer, sudoku: anytype) Action {
        self.solveN(sudoku, 1);
        return self.actionStack.getLast();
    }

    //Simply returns the last action done
    pub fn getLastAction(self: *ActionLayer) Action {
        return self.actionStack.getLast();
    }

    pub fn init(allocator: std.mem.Allocator) ActionLayer {
        return .{
            .actionStack = std.ArrayList(Action).init(allocator),
            .redoStack = std.ArrayList(Action).init(allocator),
            .boardStack = std.ArrayList([]u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ActionLayer) void {
        self.actionStack.deinit();
        self.redoStack.deinit();
        for (self.boardStack.items) |value| {
            self.allocator.free(value);
        }
        self.boardStack.deinit();
    }
};
