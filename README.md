# Bogus

Bogus aims to make your unit tests more reliable by ensuring that you don't stub or mock methods that don't actually exist in the mocked objects.

## Example

```ruby
class PostRepository
  def store(title)
    # save a new post in the database
  end
end

class PostAdder < Struct.new(:post_repository)
  def add(title)
    post = post_repository.store(title)
    # do some stuff with the post
  end
end

require 'bogus/rspec'

describe PostAdder do
  fake(:post_repository)

  it "stores the post" do
    post_adder = PostAdder.new(post_repository)
    
    post_adder.add("Bogus is safe!")

    expect(post_repository).to have_received.store("Bogus is safe!")
  end
end
```

## Features

* [Safe Stubbing][safe-stubbing] - Bogus does not allow you to stub methods that don't exist or don't match the stubbed signature.
* [Fakes][fakes] - test doubles that have the same interface as the doubled class.
* [Support for ActiveRecord models][ar-support] - Bogus comes with support for active record fields out of the box.
* [Global fake configuration][global-configuration] - Decouple your fakes from class names and define default return values in one place.
* [Contract tests][contract-tests] - a unique feature of Bogus, which reduces the need for integrated tests to a minimum by ensuring that the things you stub match how the object really behaves.

## Documentation

[You can find more detailed (and executable) documentation online.][docs]

## License

MIT. See the [LICENSE file][license].

## Authors

* [Adam Pohorecki](http://github.com/psyho)
* [Paweł Pierzchała](http://github.com/wrozka)
* [Piotr Szotkowski](https://github.com/chastell)
* [Marek Nowak](https://github.com/yundt)

[docs]: https://mostlyobvious.github.io/bogus/

[safe-stubbing]: https://mostlyobvious.github.io/bogus/safe_stubbing/
[fakes]: https://mostlyobvious.github.io/bogus/fakes/
[ar-support]: https://mostlyobvious.github.io/bogus/configuration/fake_ar_attributes/
[global-configuration]: https://mostlyobvious.github.io/bogus/fakes/global_fake_configuration/
[contract-tests]: https://mostlyobvious.github.io/bogus/contract_tests/
[license]: features/license.md
