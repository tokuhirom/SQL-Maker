# NAME

SQL::Maker - Yet another SQL builder

# SYNOPSIS

    use SQL::Maker;

    my $builder = SQL::Maker->new(
        driver => 'SQLite', # or your favorite driver
    );

    # SELECT
    ($sql, @binds) = $builder->select($table, \@fields, \%where, \%opt);

    # INSERT
    ($sql, @binds) = $builder->insert($table, \%values, \%opt);

    # DELETE
    ($sql, @binds) = $builder->delete($table, \%where);

    # UPDATE
    ($sql, @binds) = $builder->update($table, \%set, \%where);
    ($sql, @binds) = $builder->update($table, \@set, \%where);

# DESCRIPTION

SQL::Maker is yet another SQL builder class. It is based on [DBIx::Skinny](http://search.cpan.org/perldoc?DBIx::Skinny)'s SQL generator.

# METHODS

- my $builder = SQL::Maker->new(%args);

    Create new instance of SQL::Maker.

    Attributes are following:

    - driver: Str or DBI handle

        Driver name or DBI handle is required. The driver type is needed to create SQL string.

    - quote\_char: Str

        This is the character that a table or column name will be quoted with.

        Default: auto detect from $driver.

    - name\_sep: Str

        This is the character that separates a table and column name.

        Default: '.'

    - new\_line: Str

        This is the character that separates a part of statements.

        Default: '\\n'

- my $select = $builder->new\_select(%args|\\%args);

    Create new instance of [SQL::Maker::Select](http://search.cpan.org/perldoc?SQL::Maker::Select) from the settings from __$builder__.

    This method returns instance of [SQL::Maker::Select](http://search.cpan.org/perldoc?SQL::Maker::Select).

- my ($sql, @binds) = $builder->select($table|\\@tables, \\@fields, \\%where|\\@where|$where, \\%opt);

        my ($sql, @binds) = $builder->select('user', ['*'], {name => 'john'}, {order_by => 'user_id DESC'});
        # =>
        #   SELECT * FROM `user` WHERE (`name` = ?) ORDER BY user_id DESC
        #   ['john']

    This method returns SQL string and bind variables for SELECT statement.

    - $table
    - \\@tables

        Table name for __FROM__ clause in scalar or arrayref. You can specify the instance of __SQL::Maker::Select__ for sub-query.

    - \\@fields

        This is a list for retrieving fields from database.

        Each element of the `@field` is a scalar or a scalar ref of the column name normally.
        If you want to specify alias of the field, you can use ArrayRef containing the pair of column
        and alias name (e.g. `['foo.id' => 'foo_id']`).

    - \\%where
    - \\@where
    - $where

        where clause from hashref or arrayref via [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition), or [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition) object.

    - \\%opt

        This is a options for SELECT statement

        - $opt->{prefix}

            This is a prefix for SELECT statement.

            For example, you can provide the 'SELECT SQL\_CALC\_FOUND\_ROWS '. It's useful for MySQL.

            Default Value: 'SELECT '

        - $opt->{limit}

            This option makes 'LIMIT $n' clause.

        - $opt->{offset}

            This option makes 'OFFSET $n' clause.

        - $opt->{order\_by}

            This option makes __ORDER BY__ clause

            You can write it as following forms:

                $builder->select(..., order_by => 'foo DESC, bar ASC');
                $builder->select(..., order_by => ['foo DESC', 'bar ASC']);
                $builder->select(..., order_by => {foo => 'DESC'});
                $builder->select(..., order_by => [{foo => 'DESC'}, {bar => 'ASC'}]);

        - $opt->{group\_by}

            This option makes __GROUP BY__ clause

            You can write it as following forms:

                $builder->select(..., group_by => 'foo DESC, bar ASC');
                $builder->select(..., group_by => ['foo DESC', 'bar ASC']);
                $builder->select(..., group_by => {foo => 'DESC'});
                $builder->select(..., group_by => [{foo => 'DESC'}, {bar => 'ASC'}]);

        - $opt->{having}

            This option makes HAVING clause

        - $opt->{for\_update}

            This option makes 'FOR UPDATE" clause.

        - $opt->{joins}

            This option makes 'JOIN' via [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition).

- my ($sql, @binds) = $builder->insert($table, \\%values|\\@values, \\%opt);

        my ($sql, @binds) = $builder->insert(user => {name => 'john'});
        # =>
        #    INSERT INTO `user` (`name`) VALUES (?)
        #    ['john']

    Generate INSERT query.

    - $table

        Table name in scalar.

    - \\%values

        This is a values for INSERT statement.

    - \\%opt

        This is a options for INSERT statement

        - $opt->{prefix}

            This is a prefix for INSERT statement.

            For example, you can provide 'INSERT IGNORE INTO' for MySQL.

            Default Value: 'INSERT INTO'

- my ($sql, @binds) = $builder->delete($table, \\%where|\\@where|$where);

        my ($sql, @binds) = $builder->delete($table, \%where);
        # =>
        #    DELETE FROM `user` WHERE (`name` = ?)
        #    ['john']

    Generate DELETE query.

    - $table

        Table name in scalar.

    - \\%where
    - \\@where
    - $where

        where clause from hashref or arrayref via [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition), or [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition) object.

- my ($sql, @binds) = $builder->update($table, \\%set|@set, \\%where|\\@where|$where);

    Generate UPDATE query.

        my ($sql, @binds) = $builder->update('user', ['name' => 'john', email => 'john@example.com'], {user_id => 3});
        # =>
        #    'UPDATE `user` SET `name` = ?, `email` = ? WHERE (`user_id` = ?)'
        #    ['john','john@example.com',3]

    - $table

        Table name in scalar.

    - \\%set

        Setting values.

    - \\%where
    - \\@where
    - $where

        where clause from hashref or arrayref via [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition), or [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition) object.

- $builder->new\_condition()

    Create new [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition) object from ` $builder ` settings.

- my ($sql, @binds) = $builder->where(\\%where)
- my ($sql, @binds) = $builder->where(\\@where)
- my ($sql, @binds) = $builder->where(\\@where)

    Where clause from hashref or arrayref via [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition), or [SQL::Maker::Condition](http://search.cpan.org/perldoc?SQL::Maker::Condition) object.

# PLUGINS

SQL::Maker supports plugin system. Write the code like following.

    package My::SQL::Maker;
    use parent qw/SQL::Maker/;
    __PACKAGE__->load_plugin('InsertMulti');

# FAQ

- Why don't you use  SQL::Abstract?

    I need more extensible one.

    So, this module contains [SQL::Maker::Select](http://search.cpan.org/perldoc?SQL::Maker::Select), the extensible __SELECT__ clause object.

# AUTHOR

Tokuhiro Matsuno <tokuhirom AAJKLFJEF@ GMAIL COM>

# SEE ALSO

[SQL::Abstract](http://search.cpan.org/perldoc?SQL::Abstract)

Whole code was taken from [DBIx::Skinny](http://search.cpan.org/perldoc?DBIx::Skinny) by nekokak++.

# LICENSE

Copyright (C) Tokuhiro Matsuno

Copyright (C) 2004 David Baird (for dbh driver handling)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
