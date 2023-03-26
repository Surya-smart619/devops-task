# Specify the base image
FROM node:14-alpine

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
# COPY package*.json ./

# Install dependencies
RUN npm install express

# Copy the rest of the application code
COPY . .

# Expose the port that the application will run on
EXPOSE 3000

# Start the application
# CMD ["npm", "start"]
CMD ["node", "index.js"]
