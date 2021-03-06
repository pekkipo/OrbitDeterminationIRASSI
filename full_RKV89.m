function [epoch, y0state, output_state, last_point_in_E]  = full_RKV89(f,init_t,y)

    y0state = zeros(42,1);

    stop = false;

    global L2frame;
    global RKV_89_check;
    
    global rkv89_lastpiece;

    t = init_t(1); %Initial epoch
    output_state = [];
    epoch = [];
    last_point_in_E = [];

    % Set the first point
    output_state(:,1) = y;
    epoch(1) = t;
  
    % intermediary Earth frame state
    E_output_state(:,1) = y;
    
     step = 2700;
    if RKV_89_check
        step = -2700; % fixed!
    end
    while ~stop
     
    
        
   %% Value estimation  
   [errh, state] = RungeKutta89_2(f,y,t,step);
   
     y = state;
     t = t+step;
            
      if ~stop     
            % Convert state into L2-centered frame if needed
            if L2frame
                
                % Subract coordinates of L2!
                L2point = cspice_spkezr('392', t, 'J2000', 'NONE', '399');
                conv_state = state;
                conv_state(1:6) = state(1:6) - L2point;
                
                xform = cspice_sxform('J2000','L2CENTERED', t);
                L2state = xform*conv_state(1:6);
                
%                     phi = reshape(state(7:end), 6, 6);
%                     phi = xform*phi*xform^(-1);
%                     phi = reshape(phi, 36,1);
%                     L2state = [L2state; phi];
                
                output_state = [output_state, L2state];   
                E_output_state = [E_output_state, state]; 
                last_point_in_E = state;
                epoch = [epoch, t];
                
                % Now do the checking
                
                skip = 10;
             if size(output_state,2) > skip % skip first points
                 
                if ~isequal(sign(output_state(2,end-1)), sign(L2state(2,1))) %&& (L2state(1,1) < 0)
                   
                   ytol = 1e-6;
                    
                   [desired_t_for_maneuver, state_at_desired_t, state_at_desired_t_E ] = full_find_T_foryzero( [epoch(end-1) epoch(end)], E_output_state(:,end-1), ytol);                  
                   output_state(:,end) = state_at_desired_t;
                   epoch(end) = desired_t_for_maneuver;
                   last_point_in_E = state_at_desired_t_E;
                   y0state = state_at_desired_t;
                   stop = true;
                   break;
                    
                end    
                
            end 
                
                
            else  % Earth-centered frame
                output_state = [output_state, state];% , - column ; - row
                E_output_state = [E_output_state, state]; 
                last_point_in_E = state;
                epoch = [epoch, t];
                stop = true;
                
            end
            
            
      end
        
      if rkv89_lastpiece 
          if isempty(init_t(2))
             disp('Provide second epoch!'); 
          end
          tfinal = init_t(2); %must be provided as a second argument
                
              if (t + step) < tfinal 
                     step = tfinal - t; 


                  [errhh, state] = RungeKutta89_2(f,y,t,step);

                  if L2frame

                    % Subract coordinates of L2!
                    L2point = cspice_spkezr('392', t, 'J2000', 'NONE', '399');
                    conv_state = state;
                    conv_state(1:6) = state(1:6) - L2point;

                    xform = cspice_sxform('J2000','L2CENTERED', t);
                    L2state = xform*conv_state(1:6);

%                         phi = reshape(state(7:end), 6, 6);
%                         phi = xform*phi*xform^(-1);
%                         phi = reshape(phi, 36,1);
%                         L2state = [L2state; phi];

                    output_state = [output_state, L2state];   
                    E_output_state = [E_output_state, state]; 
                    last_point_in_E = state;
                    epoch = [epoch, t];
                  end

                   stop = true;
                   break
                   % break out of the loop!
                end
      end
      
            
    
    end
    
    % Convert also the first point to L2
       if L2frame
           L2point = cspice_spkezr('392', init_t(1), 'J2000', 'NONE', '399');
           conv_out1 = output_state(:,1);
           conv_out1(1:6) = output_state(1:6,1) - L2point;
           
       xform = cspice_sxform('J2000','L2CENTERED', init_t(1));
       output_state(1:6,1) = xform*conv_out1(1:6,1);
       end
    

end
