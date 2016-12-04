function gv = evaluate_V( V0 )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

%     gv = zeros(2,1);
%     d_gv = zeros(2,1);
    
    %init_state = V0;
    init_epoch = 9.747626128418571e+08;
    final_epoch = 9.903366994711639e+08;
    %positions = [5.795985038263178e+05; 7.776779586882917e+05;6.171179196351578e+05];
    positions = [0; 0;0];
    
    %init_state = V0;%[positions; V0];

    %phi0 = [1;0;0;0;0;0;0;1;0;0;0;0;0;0;1;0;0;0;0;0;0;1;0;0;0;0;0;0;1;0;0;0;0;0;0;1];
    %eye(6) would do the same :)
    %init_state = [init_state; phi0];
    
    init_state = [5.795985038263178e+05; 7.776779586882917e+05;...
    6.171179196351578e+05; -0.538364883921726; 0.286800406339146;0.125771126285189];
    V0 = [positions; V0];
    init_state = init_state + V0;
    
    phi0 = [1;0;0;0;0;0;0;1;0;0;0;0;0;0;1;0;0;0;0;0;0;1;0;0;0;0;0;0;1;0;0;0;0;0;0;1];
    init_state = [init_state;phi0];
    
    y0state = rkv89emb_maneuvers(@force_model_maneuvers, [init_epoch final_epoch], init_state, 2, true);
    disp(y0state(4));
    
    %last_ind = length(orbit);
    
   % gv = [y0state(4);y0state(6)];
   
    %d_gv = [y0state(28)'; y0state(42)'];
    %d_gv = [y0state(25:30); y0state(37:42)];
    
    % different approach
    M = y0state(7:42);
    M = reshape(M, 6,6);
    gv = M*init_state(1:6) - [y0state(1);y0state(2);y0state(3);0;y0state(5);0] + y0state(1:6); 
    
    
end

