
clc
clear all
close all

%% Define local variables
METAKR = 'planetsorbitskernels.txt';%'satelliteorbitkernels.txt';

% Settings
full_mission = false;

if not(full_mission)
    load('irassihalotime.mat', 'Date');
    load('irassihalogmat.mat', 'Gmat');
    
    
else
    load('IRASSIFullMissionDate.mat', 'Date');
    load('IRASSIFullMission.mat', 'Gmat');
end

% Load kernel
cspice_furnsh ( METAKR );

planets_name_for_struct = {'EARTH','SUN','MOON','JUPITER','VENUS','MARS','SATURN';'EARTH','SUN','301','5','VENUS','4','6'};

observer = 'EARTH';% or 339

% global G;
% G = 6.67e-20; % km % or -17


%% Ephemeris from SPICE

% Define initial epoch for a satellite
initial_utctime = '2030 MAY 22 00:03:25.693'; 
end_utctime = '2030 NOV 21 11:22:23.659';% NOV! %'2030 DEC 28 00:03:25.693'; %'2030 DEC 28 00:03:25.693';%'2030 NOV 21 11:22:23.659';
%'2030 DEC 28 00:03:25.693'; % 7 months

initial_et = cspice_str2et ( initial_utctime );
end_et = cspice_str2et ( end_utctime );

%step = 86400/10; %86400; %86400 3600 - every hour
% step = 2.6964e+03;
% %Create et time vector
% et_vector = initial_et:step:end_et;

%New approach
%Date(1,:) - way to access the first date. Date is a column vector of chars and each symbol in char is column
%datetime(Date(1,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSSSSS','TimeZone','UTC')

%et_vector = zeros(1,length(Date));

% Load full mission but starting from 3245 row, halo orbit start
%et_vector = zeros(1,11621);%zeros(1,length(Date(3245:14866,:)));%zeros(1,length(Date(3245:length(Date),:)));

if not(full_mission)
   et_vector = zeros(1,length(Date));
   for d=1:length(Date)%3245:1:14866-1%length(Date)
    %temp_vector(d) = datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC');
    % Convert form gmat date to UTC format for spice
    utcdate = datestr((datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC')), 'yyyy mmm dd HH:MM:SS.FFF');
    % Conver UTC to et
   % et_vector(d-3244) = cspice_str2et (utcdate);
   et_vector(d) = cspice_str2et (utcdate);
   end
else
    et_vector = zeros(1,11621);
     for d=3245:1:14866-1
    utcdate = datestr((datetime(Date(d,:),'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS', 'TimeZone', 'UTC')), 'yyyy mmm dd HH:MM:SS.FFF');
    et_vector(d-3244) = cspice_str2et (utcdate);
    end
end

disp(length(et_vector));



% Satellite initial position w.r.t the Earth center
initial_state = [-561844.307770134;-1023781.19884100;-152232.354717768;0.545714129191316;-0.288204299060291;-0.102116477725135]; 

% Create a structure for a satellite
sat = create_sat_structure(initial_state);

% Get initial states for calculating initial energy
[earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init] = create_structure( planets_name_for_struct, initial_et, observer);


%% ODE Integration
% Case without influence from other planets
options = odeset('RelTol',1e-12,'AbsTol',1e-12);

global influence;
influence = zeros(3,2);
pressure = 1; %0 if no solar pressure needed




%%

% tic
% orbit = ode45(@(t,y) force_model(t,y),et_vector,initial_state,options);    
% toc
% 
% tic 
% [orbit_ab8, tour] = adambashforth8(@force_model,et_vector,initial_state, length(et_vector));
% toc

% tic 
% [orbit_rkv89, tourrkv] = RKV89(@force_model,et_vector,initial_state, length(et_vector));
% toc
% 
% tic 
% [orbit_rkv89, tourrkv] = rkv(@force_model,et_vector(1), et_vector(length(et_vector)),initial_state, 60);
% toc
% 
% tic
% %orbit_rkv89_emb = zeros(6, 2000);
% orbit_rkv89_emb = zeros(6, length(et_vector));
% orbit_rkv89_emb(:,1) = initial_state;
% next_step = et_vector(2) - et_vector(1); % initial value for next_step.
% for n = 1:length(et_vector)-1
%         %next_step = et_vector(n+1) - et_vector(n);
%         [state, newstep] = rkv(@force_model,et_vector(n), et_vector(n+1),orbit_rkv89_emb(:,n), next_step);
%         next_step = newstep;      
% orbit_rkv89_emb(:,n+1) = state;
% 
% end
% toc

tic
% SO FAR CLOSE!
%orbit_rkv89_emb = zeros(6, 2000);
%orbit_rkv89_emb = zeros(6, length(et_vector));
orbit_rkv89_emb(:,1) = initial_state;
next_step = 60; % initial value for next_step.
final = false;
n = 1;
epochs(1) = et_vector(1);
while not(final)
        [state, newstep, last] = rkv(@force_model,epochs(n),orbit_rkv89_emb(:,n), next_step, et_vector(length(et_vector)));
        next_step = newstep;
        final = last;

n=n+1;
disp(n);
epochs(n) = epochs(n-1) + next_step;
orbit_rkv89_emb(:,n) = state;

end
toc

%difference = orbit_rkv89 - Gmat(:, 3245:14865);

% Integrate with maneuver inserted
%n_et = [9120, 14866]; % 2 for now
% n_et = 9120-3244; % 3244 - number of epoch before HALO orbit starts
% maneuver1 = [-0.02263165253058913;0.02267983525317713;-0.001364259283054504]; 
% %global t_at_etvector;
% %t_at_etvector = et_vector(n_et);
% for i=1:length(et_vector)
%     [orbit_rkv89, tourrkv] = RKV89(@force_model,et_vector,initial_state, length(et_vector));
%     if i == n_et
%         orbit_rkv89(4,i) = orbit_rkv89(4) + maneuver(1);
%         orbit_rkv89(5,i) = orbit_rkv89(5) + maneuver(2);
%         orbit_rkv89(6,i) = orbit_rkv89(6) + maneuver(3);
%     end
% end 

% for i=n_et+1:length(et_vector)
%     [orbit_rkv89, tourrkv] = RKV89(@force_model,et_vector,orbit_rkv89(6,n_et), length(et_vector));
%     if i == n_et
%         orbit_rkv89(4,i) = orbit_rkv89(4) + maneuver(1);
%         orbit_rkv89(5,i) = orbit_rkv89(5) + maneuver(2);
%         orbit_rkv89(6,i) = orbit_rkv89(6) + maneuver(3);
%     end
% end 

% options87 = odeset('RelTol',1e-13,'AbsTol',1e-13, 'MaxStep',2700,'InitialStep',60);
% 
% 
% %for i=1:length(et_vector)-1
% %[tour1, orbit_ode87] = ode87(@(t,y) force_model(t,y),et_vector,initial_state, options87);  
% [tour1, orbit_ode87] = ode45(@(t,y) force_model(t,y),et_vector,initial_state, options87);
% orbit_ode87 = orbit_ode87';
% % state=state';
% % final_state = state(:,size(state,2));
% % orbit_ode87(:,i+1) = final_state;
% % 
% end
% toc
%orbit_ode87 = orbit_ode87';



% % Trying to implement embedded_verner89 - SUCCESS!
% tic
% %orbit_rkv89_emb = zeros(6, 2000);
% orbit_rkv89_emb = zeros(6, length(et_vector));
% orbit_rkv89_emb(:,1) = initial_state;
% options89 = odeset('RelTol',1e-10,'AbsTol',1e-6);
% next_step = et_vector(2) - et_vector(1); % initial value for next_step.
% for n = 1:length(et_vector)-1
%         step = et_vector(n+1) - et_vector(n);
%         [tour1, values, newstep] = Embedded_Verner89(@force_model,et_vector(n), orbit_rkv89_emb(:,n), next_step, et_vector(n+1), options89.RelTol);
%         next_step = newstep;
%         % NOT SURE ABOUT THE VALUES HERE..do ir really pass a new step here
%         % or always use the same one?..though look slike Im doing it right
%     %disp(next_step);
% values = values';
% orbit_rkv89_emb(:,n+1) = values;
% 
% end
% toc

%orbit_rkv89_emb = zeros(6, 2000);
% orbit_rkv89_emb = zeros(6, length(et_vector));
% orbit_rkv89_emb(:,1) = initial_state;
% options89 = odeset('RelTol',1e-13,'AbsTol',1e-16);
% next_step = et_vector(2) - et_vector(1); % initial value for next_step.
% for n = 1:length(et_vector)-1
%         step = et_vector(n+1) - et_vector(n);
%         [flag,values, newstep] = Embedded_Verner89(@force_model,et_vector(n), orbit_rkv89_emb(:,n), next_step, et_vector(n+1), options89.RelTol);
%         next_step = newstep;
%         %disp(next_step);
% orbit_rkv89_emb(:,n+1) = values;
% 
% end
% toc


% The difference
difference_rkv89emb = abs(Gmat(:,1:5875) - orbit_rkv89_emb);
%difference_ab8 = abs(Gmat - orbit_ab8);
%difference_rkv89 = abs(Gmat - orbit_rkv89);

%difference = abs(orbit_rkv89_emb - orbit_rkv89);

% figure(7)
% grid on
% hold on
% plot(et_vector,difference(1,:),et_vector,difference(2,:),et_vector,difference(3,:) );% Reference





% for n = 1:length(et_vector)
%     next_step = []; %
%     if n == 1
%         [tour1, values, newstep] = Embedded_Verner89(@force_model,et_vector(n), initial_state, step, et_vector(n+1), step, options.AbsTol); % just step so far
%         next_step = newstep;
%     elseif n > 1 && n < length(et_vector)
%         new_initial_state = orbit_rkv89_emb(:,n-1); 
%         [tour1, values, newstep] = Embedded_Verner89(@force_model,et_vector(n), new_initial_state, step, et_vector(n+1), next_step, options.AbsTol);
%         next_step = newstep;
% %     elseif n == length(et_vector)
% %         new_initial_state = orbit_rkv89_emb(:,n-1); 
% %         [tour1, values, newstep] = Embedded_Verner89(@force_model,et_vector(n-1), new_initial_state, step, et_vector(n), next_step, options.AbsTol);
% %         next_step = newstep;
%     end
%     disp(next_step);
% values = values';
% orbit_rkv89_emb(:,n) = values;
% 
% end
% toc


%% Mechanical Energy

% energy = zeros(3, length(et_vector));  % 1 row Kinetic, 2 row Potential, 3 row - Total Mechanical
% 
% energy_ab4 = zeros(3, length(et_vector));
% First calculate the initial energies
% b = [sat, earth_init, sun_init, moon_init, jupiter_init, venus_init, mars_init, saturn_init];
% [init_total, init_kinetic, init_potential] = calculate_energy(b);
% Initial_energy = init_total;
% Initial_kinetic = init_kinetic;
% Initial_potential = init_potential;





%% Plotting

% figure(1)
% subplot(1,2,1)
% view(3)
% grid on
% hold on
% plot3(orbit.y(1,:),orbit.y(2,:),orbit.y(3,:),'r')% 
% %plot3(orbit_ab8(1,:),orbit_ab8(2,:),orbit_ab8(3,:),'g')
% subplot(1,2,2)
% view(3)
% grid on
% hold on
% plot3(Gmat(1,:),Gmat(2,:),Gmat(3,:),'b')% 

figure(3)
view(3)
grid on
hold on
plot3(Gmat(1,:),Gmat(2,:),Gmat(3,:),'b');% Reference
%plot3(orbit.y(1,:),orbit.y(2,:),orbit.y(3,:),'r');% RK45
%plot3(orbit_ab8(1,:),orbit_ab8(2,:),orbit_ab8(3,:),'g'); % ABM8
%plot3(orbit_rkv89(1,:),orbit_rkv89(2,:),orbit_rkv89(3,:),'m'); % RKV89
plot3(orbit_rkv89_emb(1,:),orbit_rkv89_emb(2,:),orbit_rkv89_emb(3,:),'c'); % RKV89 with real error estimate
%plot3(orbit_ode87(1,:),orbit_ode87(2,:),orbit_ode87(3,:),'y'); % RK87


figure(5)
grid on
hold on
%plot(et_vector,difference(1,:),et_vector,difference(2,:),et_vector,difference(3,:) );% Reference


% figure(6)
% grid on
% hold on
% plot(et_vector,difference(4,:),et_vector,difference(5,:),et_vector,difference(6,:) );% Reference



figure(5)
grid on
hold on
plot(et_vector(1,1:5875),difference_rkv89emb(1,:),et_vector(1,1:5875),difference_rkv89emb(2,:),et_vector(1,1:5875),difference_rkv89emb(3,:) );% Reference


% figure(6)
% grid on
% hold on
% plot(et_vector,difference_ab8(1,:),et_vector,difference_ab8(2,:),et_vector,difference_ab8(3,:) );% Reference

%% Plots info
% figure(1)
% title('Integrated ephemeris of a satellite w.r.t the Earth, 3D');
% subplot(1,2,1)
% legend('Integrated Orbit RK', 'Integrated Orbit AB4');
% xlabel('x');
% ylabel('y');
% zlabel('z');
% grid on
% subplot(1,2,2)
% legend('GMAT orbit');
% xlabel('x');
% ylabel('y');
% zlabel('z');
% grid on

figure(3)
title('Reference vs Integration');
legend('Reference','RK45','ABM8', 'RKV89', 'RKV89 embedded');
xlabel('x');
ylabel('y');
grid on



%cspice_kclear;