CREATE TABLE Books (
    isbn VARCHAR(13) UNIQUE PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    genre VARCHAR(255) NOT NULL,
    published_year INT NOT NULL,
    quantity_available INT NOT NULL CHECK (quantity_available >= 0)
);


CREATE TABLE Users (
    id SERIAL UNIQUE PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email_address VARCHAR(255) UNIQUE NOT NULL,
    membership_date DATE NOT NULL CHECK (membership_date <= CURRENT_DATE)
);


CREATE TABLE Book_Loans (
    loan_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    isbn VARCHAR(13) NOT NULL,
    loan_date DATE NOT NULL,
    return_date DATE,
    status VARCHAR(15) NOT NULL CHECK (status IN ('borrowed', 'returned', 'overdue')),
    FOREIGN KEY (user_id) REFERENCES Users(id),
    FOREIGN KEY (isbn) REFERENCES Books(isbn)
);

-----------------------------------------------------------------------------------------

-- Prevent Borrowing When Book Is Unavailable
CREATE OR REPLACE FUNCTION prevent_borrowing_unavailable_books()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the book has any available copies
    IF (SELECT quantity_available FROM Books WHERE isbn = NEW.isbn) <= 0 THEN
        RAISE EXCEPTION 'Book is not available';
    END IF;

    -- Decrease the quantity of available books
    UPDATE Books
    SET quantity_available = quantity_available - 1
    WHERE isbn = NEW.isbn;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_borrowing
BEFORE INSERT ON Book_Loans
FOR EACH ROW
EXECUTE FUNCTION prevent_borrowing_unavailable_books();

-------------------------------------------------------------------------------------------

-- Update Quantity on Return
CREATE OR REPLACE FUNCTION update_quantity_on_return()
RETURNS TRIGGER AS $$
BEGIN
    -- Increase the quantity of available books if the loan is marked as returned
    IF NEW.status = 'returned' AND OLD.status != 'returned' THEN
        UPDATE Books
        SET quantity_available = quantity_available + 1
        WHERE isbn = NEW.isbn;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_loan_update
AFTER UPDATE ON Book_Loans
FOR EACH ROW
EXECUTE FUNCTION update_quantity_on_return();

-------------------------------------------------------------------------------------

-- Part 3a
INSERT INTO Books (isbn, title, author, genre, published_year, quantity_available) 
VALUES ('9780439023528', 'The Hunger Games', 'Suzanne Collins', 'Fiction', 2008, 5);


-- Part 3b
INSERT INTO Users (full_name, email_address, membership_date) 
VALUES ('Kimly John Vergara', 'gmver27@gmail.com', CURRENT_DATE);


-- Part 3c
INSERT INTO Book_Loans (user_id, isbn, loan_date, status) 
VALUES (1, '9780439023528', CURRENT_DATE, 'borrowed');


-- Part 3d
SELECT b.title, b.author, bl.loan_date, bl.status
FROM Book_Loans bl
JOIN Books b ON bl.isbn = b.isbn
WHERE bl.user_id = 1
ORDER BY bl.loan_date DESC;


-- Part 3e
SELECT u.full_name, b.title, bl.loan_date, bl.return_date
FROM Book_Loans bl
JOIN Users u ON bl.user_id = u.id
JOIN Books b ON bl.isbn = b.isbn
WHERE bl.status = 'overdue'
ORDER BY bl.loan_date ASC;

-- insert another sample book
INSERT INTO Books (isbn, title, author, genre, published_year, quantity_available) 
VALUES ('9876543212345', 'Sample book', 'Sample Author', 'Fiction', 2022, 5);

-- insert overdue book loans
INSERT INTO Book_Loans (user_id, isbn, loan_date, status) 
VALUES (1, '9876543212345', CURRENT_DATE, 'overdue');


-- Create an index on Return_Date and Status columns to optimize the retrieval of overdue loans
CREATE INDEX idx_overdue_loans ON Book_Loans (Return_Date, Status);


-- Retrieve all overdue loans
SELECT u.full_name, b.title, bl.loan_date, bl.return_date
FROM Book_Loans bl
JOIN Users u ON bl.user_id = u.id
JOIN Books b ON bl.isbn = b.isbn
WHERE bl.status = 'overdue'
ORDER BY bl.loan_date ASC;

