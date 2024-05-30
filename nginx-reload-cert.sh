#!/bin/bash

# Function to gracefully restart Nginx with debug and fail-safe mechanisms
restart_nginx_gracefully() {
  NGINX_CMD="/usr/sbin/nginx"
  NGINX_CONF="/etc/nginx/nginx.conf"
  NGINX_PID_FILE="/var/run/nginx.pid"
  NGINX_NEW_PID_FILE="/var/run/nginx.pid.oldbin"
  TIMEOUT=30  # Maximum number of seconds to wait for processes

  log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message"
  }

  # Check if the Nginx configuration is valid
  log "Checking Nginx configuration..."
  if $NGINX_CMD -t -c $NGINX_CONF; then
    log "Nginx configuration is valid."
  else
    log "Nginx configuration is invalid. Aborting reload."
    return 1
  fi

  # Check if the Nginx master process PID file exists
  if [ ! -f $NGINX_PID_FILE ]; then
    log "Nginx PID file not found. Is Nginx running? Aborting reload."
    return 1
  fi

  # Send USR2 signal to Nginx master process to reload configuration
  log "Sending USR2 signal to Nginx master process..."
  sudo kill -USR2 $(cat $NGINX_PID_FILE)
  if [ $? -eq 0 ]; then
    log "USR2 signal sent successfully. Waiting for new Nginx master process to start..."
  else
    log "Failed to send USR2 signal. Please check the system logs for details."
    return 1
  fi

  # Wait for the new Nginx master process to start
  local elapsed=0
  while [ ! -f $NGINX_NEW_PID_FILE ] && [ $elapsed -lt $TIMEOUT ]; do
    sleep 1
    elapsed=$((elapsed + 1))
  done

  if [ -f $NGINX_NEW_PID_FILE ]; then
    log "New Nginx master process started successfully."
  else
    log "New Nginx master process did not start within $TIMEOUT seconds. Aborting."
    return 1
  fi

  # Gracefully shut down the old master process
  log "Sending QUIT signal to old Nginx master process to gracefully shut down..."
  sudo kill -QUIT $(cat $NGINX_NEW_PID_FILE)
  if [ $? -eq 0 ]; then
    log "QUIT signal sent successfully. Waiting for old Nginx master process to shut down..."
  else
    log "Failed to send QUIT signal. Please check the system logs for details."
    return 1
  fi

  # Wait for the old master process to shut down
  elapsed=0
  while [ -f $NGINX_NEW_PID_FILE ] && [ $elapsed -lt $TIMEOUT ]; do
    sleep 1
    elapsed=$((elapsed + 1))
  done

  if [ ! -f $NGINX_NEW_PID_FILE ]; then
    log "Old Nginx master process shut down successfully."
  else
    log "Old Nginx master process did not shut down within $TIMEOUT seconds. Manual intervention may be required."
    return 1
  fi

  log "Nginx graceful restart completed successfully."
}

# Example usage of the function
# You can call this function after cert renewal
restart_nginx_gracefully
