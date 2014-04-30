set logscale z 10
set view 20, 340, 1, 1
set isosamples 60, 60
set hidden3d offset 1 trianglepattern 3 undefined 1 altdiagonal bentover
set style data lines
set ticslevel 0
set title "Rosenbrock Function" offset 0.000000,0.000000  
set xlabel "x" offset -5.000000,-2.000000  
set xrange [ * : * ] noreverse nowriteback  # (currently [0.00000:15.0000] )
set ylabel "y" offset 4.000000,-1.000000  
set yrange [ * : * ] noreverse nowriteback  # (currently [0.00000:15.0000] )
set zlabel "z" offset 0.000000,0.000000  
set zrange [ * : * ] noreverse nowriteback  # (currently [-1.20000:1.20000] )
splot [-1.5:1.5] [-0.5:1.5] (1-x)**2 + 100*(y - x**2)**2
