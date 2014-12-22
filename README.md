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
    ($sql, @binds) = $builder->delete($table, \%where, \%opt);

    # UPDATE
    ($sql, @binds) = $builder->update($table, \%set, \%where);
    ($sql, @binds) = $builder->update($table, \@set, \%where);

# DESCRIPTION

SQL::Maker is yet another SQL builder class. It is based on [DBIx::Skinny](https://metacpan.org/pod/DBIx::Skinny)'s SQL generator.

# METHODS

- `my $builder = SQL::Maker->new(%args);`

    Create new instance of SQL::Maker.

    Attributes are the following:

    - driver: Str

        Driver name is required. The driver type is needed to create SQL string.

    - quote\_char: Str

        This is the character that a table or column name will be quoted with.

        Default: auto detect from $driver.

    - name\_sep: Str

        This is the character that separates a table and column name.

        Default: '.'

    - new\_line: Str

        This is the character that separates a part of statements.

        Default: '\\n'

    - strict: Bool

        Whether or not the use of unblessed references are prohibited for defining the SQL expressions.

        In strict mode, all the expressions must be declared by using blessed references that export `as_sql` and `bind` methods like [SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker).
        See ["STRICT MODE"](#strict-mode) for detail.

        Default: undef

- `my $select = $builder->new_select(%args|\%args);`

    Create new instance of [SQL::Maker::Select](https://metacpan.org/pod/SQL::Maker::Select) using the settings from **$builder**.

    This method returns an instance of [SQL::Maker::Select](https://metacpan.org/pod/SQL::Maker::Select).

- `my ($sql, @binds) = $builder->select($table|\@tables, \@fields, \%where|\@where|$where, \%opt);`

        my ($sql, @binds) = $builder->select('user', ['*'], {name => 'john'}, {order_by => 'user_id DESC'});
        # =>
        #   SELECT * FROM `user` WHERE (`name` = ?) ORDER BY user_id DESC
        #   ['john']

    This method returns the SQL string and bind variables for a SELECT statement.

    - `$table`
    - `\@tables`

        Table name for the **FROM** clause as scalar or arrayref. You can specify the instance of **SQL::Maker::Select** for a sub-query.

        If you are using `$opt->{joins}` this should be _undef_ since it's passed via the first join.

    - `\@fields`

        This is a list for retrieving fields from database.

        Each element of the `@fields` is normally a scalar or a scalar ref containing the column name.
        If you want to specify an alias of the field, you can use an arrayref containing a pair
        of column and alias names (e.g. `['foo.id' => 'foo_id']`).

    - `\%where`
    - `\@where`
    - `$where`

        where clause from hashref or arrayref via [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition), or [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition) object, or [SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker) object.

    - `\%opt`

        These are the options for the SELECT statement

        - `$opt->{prefix}`

            This is a prefix for the SELECT statement.

            For example, you can provide the 'SELECT SQL\_CALC\_FOUND\_ROWS '. It's useful for MySQL.

            Default Value: 'SELECT '

        - `$opt->{limit}`

            This option adds a 'LIMIT $n' clause.

        - `$opt->{offset}`

            This option adds an 'OFFSET $n' clause.

        - `$opt->{order_by}`

            This option adds an **ORDER BY** clause

            You can write it in any of the following forms:

                $builder->select(..., {order_by => 'foo DESC, bar ASC'});
                $builder->select(..., {order_by => ['foo DESC', 'bar ASC']});
                $builder->select(..., {order_by => {foo => 'DESC'}});
                $builder->select(..., {order_by => [{foo => 'DESC'}, {bar => 'ASC'}]});

        - `$opt->{group_by}`

            This option adds a **GROUP BY** clause

            You can write it in any of the following forms:

                $builder->select(..., {group_by => 'foo DESC, bar ASC'});
                $builder->select(..., {group_by => ['foo DESC', 'bar ASC']});
                $builder->select(..., {group_by => {foo => 'DESC'}});
                $builder->select(..., {group_by => [{foo => 'DESC'}, {bar => 'ASC'}]});

        - `$opt->{having}`

            This option adds a HAVING clause

        - `$opt->{for_update}`

            This option adds a 'FOR UPDATE" clause.

        - `$opt->{joins}`

            This option adds a 'JOIN' via [SQL::Maker::Select](https://metacpan.org/pod/SQL::Maker::Select).

            You can write it as follows:

                $builder->select(undef, ..., {joins => [[user => {table => 'group', condition => 'user.gid = group.gid'}], ...]});

        - `$opt->{index_hint}`

            This option adds an INDEX HINT like as 'USE INDEX' clause for MySQL via [SQL::Maker::Select](https://metacpan.org/pod/SQL::Maker::Select).

            You can write it as follows:

                $builder->select(..., { index_hint => 'foo' });
                $builder->select(..., { index_hint => ['foo', 'bar'] });
                $builder->select(..., { index_hint => { list => 'foo' });
                $builder->select(..., { index_hint => { type => 'FORCE', list => ['foo', 'bar'] });

- `my ($sql, @binds) = $builder->insert($table, \%values|\@values, \%opt);`

        my ($sql, @binds) = $builder->insert(user => {name => 'john'});
        # =>
        #    INSERT INTO `user` (`name`) VALUES (?)
        #    ['john']

    Generate an INSERT query.

    - `$table`

        Table name in scalar.

    - `\%values`

        These are the values for the INSERT statement.

    - `\%opt`

        These are the options for the INSERT statement

        - `$opt->{prefix}`

            This is a prefix for the INSERT statement.

            For example, you can provide 'INSERT IGNORE INTO' for MySQL.

            Default Value: 'INSERT INTO'

- `my ($sql, @binds) = $builder->delete($table, \%where|\@where|$where, \%opt);`

        my ($sql, @binds) = $builder->delete($table, \%where);
        # =>
        #    DELETE FROM `user` WHERE (`name` = ?)
        #    ['john']

    Generate a DELETE query.

    - `$table`

        Table name in scalar.

    - `\%where`
    - `\@where`
    - `$where`

        where clause from hashref or arrayref via [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition), or [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition) object, or [SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker) object.

    - `\%opt`

        These are the options for the DELETE statement

        - `$opt->{using}`

            This option adds a USING clause. It takes a scalar or an arrayref of table names as argument:

                my ($sql, $binds) = $bulder->delete($table, \%where, { using => 'group' });
                # =>
                #    DELETE FROM `user` USING `group` WHERE (`group`.`name` = ?)
                #    ['doe']
                $bulder->delete(..., { using => ['bar', 'qux'] });

- `my ($sql, @binds) = $builder->update($table, \%set|@set, \%where|\@where|$where);`

    Generate a UPDATE query.

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

        where clause from a hashref or arrayref via [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition), or [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition) object, or [SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker) object.

- `$builder->new_condition()`

    Create new [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition) object from ` $builder ` settings.

- `my ($sql, @binds) = $builder->where(\%where)`
- `my ($sql, @binds) = $builder->where(\@where)`
- `my ($sql, @binds) = $builder->where(\@where)`

    Where clause from a hashref or arrayref via [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition), or [SQL::Maker::Condition](https://metacpan.org/pod/SQL::Maker::Condition) object, or [SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker) object.

# PLUGINS

SQL::Maker features a plugin system. Write the code as follows:

    package My::SQL::Maker;
    use parent qw/SQL::Maker/;
    __PACKAGE__->load_plugin('InsertMulti');

# STRICT MODE

See [http://blog.kazuhooku.com/2014/07/the-json-sql-injection-vulnerability.html](http://blog.kazuhooku.com/2014/07/the-json-sql-injection-vulnerability.html) for why
do we need the strict mode in the first place.

In strict mode, the following parameters must be blessed references implementing `as_sql` and `bind` methods
if they are NOT simple scalars (i.e. if they are references of any kind).

- Values in `$where` parameter for `select`, `update`, `delete` methods.
- Values in `%values` and `%set` parameter for `insert` and `update` methods, respectively.

You can use [SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker) objects for those parameters.

Example:

    use SQL::QueryMaker qw(sql_in sql_raw);
    
    ## NG: Use array-ref for values.
    $maker->select("user", ['*'], { name => ["John", "Tom"] });
    
    ## OK: Use SQL::QueryMaker
    $maker->select("user", ['*'], { name => sql_in(["John", "Tom"]) });
    
    ## Also OK: $where parameter itself is a blessed object.
    $maker->select("user", ['*'], $maker->new_condition->add(name => sql_in(["John", "Tom"])));
    $maker->select("user", ['*'], sql_in(name => ["John", "Tom"]));
    
    
    ## NG: Use scalar-ref for a raw value.
    $maker->insert(user => [ name => "John", created_on => \"datetime(now)" ]);
    
    ## OK: Use SQL::QueryMaker
    $maker->insert(user => [name => "John", created_on => sql_raw("datetime(now)")]);

# FAQ

- Why don't you use SQL::Abstract?

    I need a more extensible one.

    So, this module contains [SQL::Maker::Select](https://metacpan.org/pod/SQL::Maker::Select), the extensible **SELECT** clause object.

# AUTHOR

Tokuhiro Matsuno <tokuhirom AAJKLFJEF@ GMAIL COM>

# SEE ALSO

[SQL::Abstract](https://metacpan.org/pod/SQL::Abstract)
[SQL::QueryMaker](https://metacpan.org/pod/SQL::QueryMaker)

The whole code was taken from [DBIx::Skinny](https://metacpan.org/pod/DBIx::Skinny) by nekokak++.

# LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
