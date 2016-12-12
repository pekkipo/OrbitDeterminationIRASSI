
METAKR = which('planetsorbitskernels.txt');
cspice_furnsh ( METAKR );

% Set initial state

 R0 = [5.470091051396191e+05;7.746809140774258e+05;6.136761030644372e+05];
 V0 =  [-0.561328688405743;0.285354232749995;0.124723965335411];
% Initial Time
initial_time = 9.748741253169044e+08;
% Final Time
final_time = 10000.140558185330e+006;


phi0 = reshape(eye(6), 36, 1);
init_state = [R0; V0; phi0];


global G;
G = 6.673e-20;
global L2frame;
L2frame = true;
global checkrkv89_emb
checkrkv89_emb = false;

% Initial guess
dV = [-7.803777280688135e-04; 0.001854569833090; -0.007247538179753];

%options = optimoptions('fsolve','TolFun', 1e-4, 'TolX', 1e-4);
deltaV = fsolve(@evaluate_V_test, dV);
disp(deltaV);

Init_state = init_state;
Init_state(4:6,:) = Init_state(4:6,:)+ deltaV;
[t, y0state, output_state, y0state_E] = full_rkv89emb_maneuvers(@full_force_model, initial_time , Init_state);

% Init_state is the new value 
% y0state is the state, from which the next integration should start


% Graphical check of the orbit part
figure
hold on
plot3(output_state(1,:),output_state(2,:),output_state(3,:),'r','LineWidth',2)

