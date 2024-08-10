FROM ruby:3.1

# Dependencies
RUN apt-get update -qq && apt-get install -y build-essential
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Set the working directory
WORKDIR /scale_rb
COPY . /scale_rb

# Intall gems
RUN bundle install

# default command is to run a shell
CMD ["bash"]