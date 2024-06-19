"""
Calculate and plot the amount of space required to store
the different kind of sudoku board representations.

We are comparing a simple 2D matrix storage implementation (Square)
with a bitfield implementation that stores each constraint (Row, Col, Grid)
in a single size-wide integer, up to 65536 bits wide.
"""

import numpy as np
import pandas as pd
import plotly.graph_objects as go


# Define the functions
def b(x):
    """Find the number of bits needed to store x."""
    return np.floor(np.log2(x)) + 1


def f(k):
    """Calculate the storage size for a normal 2D matrix storage implementation."""
    size = k * k
    return (size * size) * b(size)


def g(k):
    """Calculate the storage size for a bitfield storage implementation."""
    size = k * k
    return (2 * size + 2 * k) * size


def a(k):
    """Calculate the combined storage size for both implementations."""
    return f(k) + g(k)


# Define the range of k values to evaluate
k_values = np.arange(3, 11, 1)

# Calculate the function values
f_values = f(k_values)
g_values = g(k_values)
a_values = a(k_values)

# Create a DataFrame for better visualization
data = {
    'k':    k_values,
    'f(k)': f_values,
    'g(k)': g_values,
    'a(k)': a_values
}
df = pd.DataFrame(data)

# Plotting the values using Plotly
fig = go.Figure()

fig.add_trace(go.Scatter(x=df['k'], y=df['f(k)'], mode='lines+markers', name='Normal storage', marker=dict(size=8)))
fig.add_trace(go.Scatter(x=df['k'], y=df['g(k)'], mode='lines+markers', name='Bitfield storage', marker=dict(size=8)))
fig.add_trace(go.Scatter(x=df['k'], y=df['a(k)'], mode='lines+markers', name='Combined', marker=dict(size=8)))

# Add titles and labels
fig.update_layout(
    title='Comparison of Function Values',
    xaxis_title='Sudoku K (And N)',
    yaxis_title='Total Bits Needed (Storage Size)',
    legend_title='Functions',
    template='plotly_dark'
)

# Show the plot
fig.show()

# Display the DataFrame
print(df)
